#!/bin/bash

set -e

# Input
GAIA_A_USER1_NAME="gaiaA-1_local-bank"
GAIA_A_USER2_NAME="gaiaA-1_local-validator-1"
GAIA_B_USER1_NAME="gaiaB-1_local-bank"

CHANNEL_ID="channel-0"
PORT_ID="chat"

CMD_KEYS_GAIA="gaiad keys --keyring-backend os"
CMD_TX_GAIA_A="gaiad tx --chain-id gaiaA-1 --node tcp://localhost:26671 --keyring-backend os"
CMD_Q_GAIA_A="gaiad q --node tcp://localhost:26671"
CMD_TX_GAIA_B="gaiad tx --chain-id gaiaB-1 --node tcp://localhost:26771 --keyring-backend os"
CMD_Q_GAIA_B="gaiad q --node tcp://localhost:26771"
#

# State
GAIA_A_USER1_ADDR=""
GAIA_A_USER2_ADDR=""
GAIA_B_USER1_ADDR=""
#

# Get account address
function SetUsersAddress() {
    GAIA_A_USER1_ADDR=$(${CMD_KEYS_GAIA} show -a ${GAIA_A_USER1_NAME})
    GAIA_A_USER2_ADDR=$(${CMD_KEYS_GAIA} show -a ${GAIA_A_USER2_NAME})
    GAIA_B_USER1_ADDR=$(${CMD_KEYS_GAIA} show -a ${GAIA_B_USER1_NAME})
    echo "A. User address 1: ${GAIA_A_USER1_ADDR}"
    echo "A. User address 2: ${GAIA_A_USER2_ADDR}"
    echo "B. User address 1: ${GAIA_B_USER1_ADDR}"
}

# GaiaA -> GaiaA. Send message localy (no IBC involved)
function ASendMessageLocaly() {
    from_addr="$1"
    to_addr="$2"
    text="$3"

    ${CMD_TX_GAIA_A} chat send ${to_addr} "${text}" --from ${from_addr} -y -b block | pbcopy
    echo "Message (${from_addr} -> ${to_addr}) send"
}

# GaiaA -> GaiaB. Send message via IBC
function ASendMessageViaIBC() {
    from_addr="$1"
    to_addr="$2"
    channel_id="$3"
    port_id="$4"
    text="$5"

    ${CMD_TX_GAIA_A} chat send ${to_addr} "${text}" --from ${from_addr} --dst-channel-id ${channel_id} --dst-port-id ${port_id} -y -b block | pbcopy
    echo "Message (${from_addr} -> ${to_addr} over ${channel_id}.${port_id}) send"
}

# GaiaB -> GaiaA. Send message via IBC
function BSendMessageViaIBC() {
    from_addr="$1"
    to_addr="$2"
    channel_id="$3"
    port_id="$4"
    text="$5"

    ${CMD_TX_GAIA_B} chat send ${to_addr} "${text}" --from ${from_addr} --dst-channel-id ${channel_id} --dst-port-id ${port_id} -y -b block | pbcopy
    echo "Message (${from_addr} -> ${to_addr} over ${channel_id}.${port_id}) send"
}

# GaiaA. Print message history
function APrintHistory() {
    addr_1="$1"
    addr_2="$2"

    ${CMD_Q_GAIA_A} chat history ${addr_1} ${addr_2}
}

# GaiaB. Print message history
function BPrintHistory() {
    addr_1="$1"
    addr_2="$2"

    ${CMD_Q_GAIA_B} chat history ${addr_1} ${addr_2}
}

# Main

SetUsersAddress

while [[ $# -gt 0 ]]; do
    case $1 in
        a-send-local)
            shift
            echo "-> Sending message GaiaA->GaiaA"
            if [ $# -eq 0 ]; then
                echo "Usage: a-send-local text"
                exit 1
            fi
            msg_text="$1"
            shift

            ASendMessageLocaly ${GAIA_A_USER1_ADDR} ${GAIA_A_USER2_ADDR} "${msg_text}"
            ;;
        a-send-ibc)
            shift
            echo "-> Sending message GaiaA->GaiaB"
            if [ $# -eq 0 ]; then
                echo "Usage: a-send-ibc text"
                exit 1
            fi
            msg_text="$1"
            shift

            ASendMessageViaIBC ${GAIA_A_USER1_ADDR} ${GAIA_B_USER1_ADDR} ${CHANNEL_ID} ${PORT_ID} "${msg_text}"
            ;;
        b-send-ibc)
            shift
            echo "-> Sending message GaiaB->GaiaA"
            if [ $# -eq 0 ]; then
                echo "Usage: b-send-ibc text"
                exit 1
            fi
            msg_text="$1"
            shift

            BSendMessageViaIBC ${GAIA_B_USER1_ADDR} ${GAIA_A_USER1_ADDR} ${CHANNEL_ID} ${PORT_ID} "${msg_text}"
            ;;
        a-history-local)
            shift
            echo "-> Printing GaiaA local message history"

            APrintHistory ${GAIA_A_USER1_ADDR} ${GAIA_A_USER2_ADDR}
            ;;
        a-history-ibc)
            shift
            echo "-> Printing GaiaA IBC message history"

            APrintHistory ${GAIA_A_USER1_ADDR} ${GAIA_B_USER1_ADDR}
            ;;
        b-history-ibc)
            shift
            echo "-> Printing GaiaB IBC message history"

            APrintHistory ${GAIA_B_USER1_ADDR} ${GAIA_A_USER1_ADDR}
            ;;
        *)
            echo "Unsupported cmd"
            exit 1
        ;;
    esac
done

# Cmds
# ./node_cluster_init.sh -c config/gaiaA.sh; ./node_cluster_init.sh -c config/gaiaB.sh; ./node_cluster_run.sh -c config/gaiaA.sh; ./node_cluster_run.sh -c config/gaiaB.sh; ./relayer_init.sh -c config/relayer_gaiaAB.sh; ./relayer_run.sh -c config/relayer_gaiaAB.sh
# ./stop_cluster.sh -c config/gaiaA.sh; ./stop_cluster.sh -c config/gaiaB.sh; ./stop_relayer.sh -c config/relayer_gaiaAB.sh
