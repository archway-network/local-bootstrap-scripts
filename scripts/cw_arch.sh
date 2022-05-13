#!/bin/bash

set -e

# Input
CW_USER1_NAME="arch-1_local-bank"
CW_USER2_NAME="arch-1_local-validator-1"
GAIA_USER1_NAME="gaiaB-1_local-bank"

CHANNEL_ID="channel-0"
GAIA_PORT_ID="chat"

CONTRACT_BYTECODE_PATH="${HOME}/Rust_Projects/archway/chat-contract/target/wasm32-unknown-unknown/release/cw_chat.wasm"
CONTRACT_LABEL="chat"

RELAYER_CONFIG="${HOME}/Archway/local-bootstrap-scripts/config/relayer_archGaiaB.sh"

CMD_KEYS_CW="archwayd keys --keyring-backend os"
CMD_TX_CW="archwayd tx --chain-id arch-1 --node tcp://localhost:26671 --keyring-backend os"
CMD_Q_CW="archwayd q --node tcp://localhost:26671"

CMD_KEYS_GAIA="gaiad keys --keyring-backend os"
CMD_TX_GAIA="gaiad tx --chain-id gaiaB-1 --node tcp://localhost:26771 --keyring-backend os"
CMD_Q_GAIA="gaiad q --node tcp://localhost:26771"

GAS=2000000
#

# State
CW_USER1_ADDR=""
CW_USER2_ADDR=""
GAIA_USER1_ADDR=""

CODE_ID=""
CONTRACT_ADDR=""
CONTRACT_PORT_ID=""
#

# Templates
MSG_INSTANTIATE="{}"
MSG_SEND_TEMPLATE='{ "send":{ "to_address": "{toAddr}", "ibc_channel_id": "{ibcChannelID}", "text": "{text}" } }'

QUERY_HISTORY_TEMPALE='{ "history": { "participant1_address": "{addr1}", "participant2_address": "{addr2}" } }'
#

# Get account address
function SetUsersAddress() {
    CW_USER1_ADDR=$(${CMD_KEYS_CW} show -a ${CW_USER1_NAME})
    CW_USER2_ADDR=$(${CMD_KEYS_CW} show -a ${CW_USER2_NAME})
    GAIA_USER1_ADDR=$(${CMD_KEYS_GAIA} show -a ${GAIA_USER1_NAME})
    echo "CowmWasm. User address 1: ${CW_USER1_ADDR}"
    echo "CowmWasm. User address 2: ${CW_USER2_ADDR}"
    echo "Gaia. User address 1: ${GAIA_USER1_ADDR}"
}

# Upload and get codeID
function UploadCodeAndGetID() {
    ${CMD_TX_CW} wasm store "${CONTRACT_BYTECODE_PATH}" --from ${CW_USER1_ADDR} --gas ${GAS} --output json -y -b block | pbcopy
    CODE_ID=$(pbpaste | jq -r '.logs[0].events[] | select(.type=="store_code") | .attributes[0].value')
    echo "CodeID: ${CODE_ID}"
}

# Instantiate and get contractAddress
function InstantiateAndGetAddress() {
    ${CMD_TX_CW} wasm instantiate ${CODE_ID} "${MSG_INSTANTIATE}" --label "${CONTRACT_LABEL}" --no-admin --from ${CW_USER1_ADDR} --output json --gas ${GAS} -y -b block | pbcopy
    CONTRACT_ADDR=$(pbpaste | jq -r '.logs[0].events[] | select(.type=="instantiate") | .attributes[] | select(.key=="_contract_address").value')
    echo "ContractAddress: ${CONTRACT_ADDR}"
}

# Get latest uploaded codeID and instanceID
function SelectLatestCodeInstance() {
    ${CMD_Q_CW} wasm list-code --output json | pbcopy
    CODE_ID=$(pbpaste | jq -r '.code_infos[] | select(.creator=="'"${CW_USER1_ADDR}"'") | .code_id' | sort -n | tail -1)
    echo "Latest codeID: ${CODE_ID}"

    ${CMD_Q_CW} wasm list-contract-by-code ${CODE_ID} --output json | pbcopy
    CONTRACT_ADDR=$(pbpaste | jq -r '.contracts[]' | tail -1)
    echo "Latest contractAddress: ${CONTRACT_ADDR}"

    ${CMD_Q_CW} wasm contract ${CONTRACT_ADDR} --output json | pbcopy
    CONTRACT_PORT_ID=$(pbpaste | jq -r '.contract_info.ibc_port_id')
    echo "Latest contractPortID: ${CONTRACT_PORT_ID}"
}

# Get contract IBC portID and set it for relayer config
function FixPortIDForRelayerConfig() {
    ${CMD_Q_CW} wasm contract ${CONTRACT_ADDR} --output json | pbcopy
    CONTRACT_PORT_ID=$(pbpaste | jq -r '.contract_info.ibc_port_id')
    echo "ContractPortID: ${CONTRACT_PORT_ID}"

    sed -i.bak -e 's;CONTRACT_PORT_ID=\".*\";CONTRACT_PORT_ID=\"'"${CONTRACT_PORT_ID}"'\";' "${RELAYER_CONFIG}"
    rm "${RELAYER_CONFIG}.bak"
    echo "Relayer config fixed: ${RELAYER_CONFIG}"
}

# CowmWasm -> CosmWasm. Send message localy (no IBC involved)
function CWSendMessageLocaly() {
    from_addr="$1"
    to_addr="$2"
    text="$3"

    msg=$(echo ${MSG_SEND_TEMPLATE} | sed -e 's;{toAddr};'"${to_addr}"';')
    msg=$(echo ${msg} | sed -e 's;{ibcChannelID};;')
    msg=$(echo ${msg} | sed -e 's;{text};'"${text}"';')

    ${CMD_TX_CW} wasm execute ${CONTRACT_ADDR} "${msg}" --from ${from_addr} --gas ${GAS} -y -b block | pbcopy
    echo "Message (${from_addr} -> ${to_addr}) send:"; echo ${msg} | jq
}

# CosmWasm -> Gaia. Send message via IBC
function CWSendMessageViaIBC() {
    from_addr="$1"
    to_addr="$2"
    channel_id="$3"
    text="$4"

    msg=$(echo ${MSG_SEND_TEMPLATE} | sed -e 's;{toAddr};'"${to_addr}"';')
    msg=$(echo ${msg} | sed -e 's;{ibcChannelID};'"${channel_id}"';')
    msg=$(echo ${msg} | sed -e 's;{text};'"${text}"';')

    ${CMD_TX_CW} wasm execute ${CONTRACT_ADDR} "${msg}" --from ${from_addr} --gas ${GAS} -y -b block | pbcopy
    echo "Message (${from_addr} -> ${to_addr} over ${channel_id}) send:"; echo ${msg} | jq
}

# Gaia -> CosmWasm. Send message via IBC
function GaiaSendMessageViaIBC() {
    from_addr="$1"
    to_addr="$2"
    channel_id="$3"
    port_id="$4"
    text="$5"

    ${CMD_TX_GAIA} chat send ${to_addr} "${text}" --from ${from_addr} --dst-channel-id ${channel_id} --dst-port-id ${port_id} -y -b block
    echo "Message (${from_addr} -> ${to_addr} over ${channel_id}.${port_id}) send"
}

# CosmWasm. Print message history
function CWPrintHistory() {
    addr_1="$1"
    addr_2="$2"

    query=$(echo ${QUERY_HISTORY_TEMPALE} | sed -e 's;{addr1};'"${addr_1}"';')
    query=$(echo ${query} | sed -e 's;{addr2};'"${addr_2}"';')

    echo "History (${addr_1} <-> ${addr_2}):"
    ${CMD_Q_CW} wasm contract-state smart ${CONTRACT_ADDR} "${query}" --output json | jq '.data.text_messages[]'
}

# Gaia. Print message history
function GaiaPrintHistory() {
    addr_1="$1"
    addr_2="$2"

    ${CMD_Q_GAIA} chat history ${addr_1} ${addr_2}
}

# Main

SetUsersAddress

while [[ $# -gt 0 ]]; do
    case $1 in
        cw-init)
            shift
            echo "-> Deploying contract"
            UploadCodeAndGetID
            InstantiateAndGetAddress
            FixPortIDForRelayerConfig
            ;;
        cw-send-local)
            shift
            echo "-> Sending message CosmWasm->CosmWasm"
            if [ $# -eq 0 ]; then
                echo "Usage: cw-send-local text"
                exit 1
            fi
            msg_text="$1"
            shift

            SelectLatestCodeInstance
            CWSendMessageLocaly ${CW_USER1_ADDR} ${CW_USER2_ADDR} "${msg_text}"
            ;;
        cw-send-ibc)
            shift
            echo "-> Sending message CosmWasm->Gaia"
            if [ $# -eq 0 ]; then
                echo "Usage: cw-send-ibc text"
                exit 1
            fi
            msg_text="$1"
            shift

            SelectLatestCodeInstance
            CWSendMessageViaIBC ${CW_USER1_ADDR} ${GAIA_USER1_ADDR} ${CHANNEL_ID} "${msg_text}"
            ;;
        gaia-send-ibc)
            shift
            echo "-> Sending message Gaia->CosmWasm"
            if [ $# -eq 0 ]; then
                echo "Usage: gaia-send-ibc text"
                exit 1
            fi
            msg_text="$1"
            shift

            SelectLatestCodeInstance
            GaiaSendMessageViaIBC ${GAIA_USER1_ADDR} ${CW_USER1_ADDR} ${CHANNEL_ID} ${GAIA_PORT_ID} "${msg_text}"
            ;;
        cw-history-local)
            shift
            echo "-> Printing CosmWasm local message history"

            SelectLatestCodeInstance
            CWPrintHistory ${CW_USER1_ADDR} ${CW_USER2_ADDR}
            ;;
        cw-history-ibc)
            shift
            echo "-> Printing CosmWasm IBC message history"

            SelectLatestCodeInstance
            CWPrintHistory ${CW_USER1_ADDR} ${GAIA_USER1_ADDR}
            ;;
        gaia-history-ibc)
            shift
            echo "-> Printing Gaia IBC message history"

            GaiaPrintHistory ${CW_USER1_ADDR} ${GAIA_USER1_ADDR}
            ;;
        *)
            echo "Unsupported cmd"
            exit 1
        ;;
    esac
done

# Cmds
# ./node_cluster_init.sh -c config/arch-1.sh; ./node_cluster_init.sh -c config/gaiaB.sh; ./node_cluster_run.sh -c config/arch-1.sh; ./node_cluster_run.sh -c config/gaiaB.sh; ./wait_for_block.sh -c config/arch-1.sh 2
# ./scripts/cw_arch.sh cw-init
# ./relayer_init.sh -c config/relayer_archGaiaB.sh; ./relayer_run.sh -c config/relayer_archGaiaB.sh
# ./stop_cluster.sh -c config/arch-1.sh; ./stop_cluster.sh -c config/gaiaB.sh; ./stop_relayer.sh -c config/relayer_archGaiaB.sh
