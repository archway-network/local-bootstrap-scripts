#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

set -e

# Chain related variables.
CMD_KEYS="" # CLI command to get keys
CMD_TX=""   # CLI command to send tx
CMD_Q=""    # CLI command to query
#

# Tx defaults.
## Set gas and, optionally, fees to override function default values.
## For a function default gas, fees are estimated.
## Values are cleaned up after the tx is sent.
NEXT_TX_GAS="" # next transaction gas limit
NEXT_TX_FEES="" # next transaction fees
#

# WASM contract related variables (set by different functions).
CONTRACT_CODE_ID="" # WASM contract code ID
CONTRACT_ADDRESS="" # WASM contract address (set by InstantiateCodeWithAdmin / InstantiateCode)
#

# Other.
DEF_GOV_DEPOSIT="" # default gov deposit
#

# ---------- Setup -----------------------------------------------------------------------------------------------------

# Setup CLI default by chainConfig.
## Sets: CMD_KEYS, CMD_TX, CMD_Q, DEF_FEES.
function SetupChainParams() {
  chain_config="$1"

  echo "-> Default setup based on chain config: ${chain_config}"
    source "${chain_config}"
    source "$(dirname ${DIR})/lib/node/common.sh"

    CMD_KEYS="${COSMOSD} keys --keyring-backend ${KEYRING_BACKEND}"
    CMD_TX="${COSMOSD} tx --chain-id ${CHAIN_ID} --node tcp://localhost:${NODE_RPC_PORT_PREFIX}1 --keyring-backend ${KEYRING_BACKEND}"
    CMD_Q="${COSMOSD} q --node tcp://localhost:${NODE_RPC_PORT_PREFIX}1"

    DEF_GOV_DEPOSIT="10000000${STAKE_DENOM}"
  echo
}

# --------- Banking operations -----------------------------------------------------------------------------------------

# Get account balance for $1 account address.
function GetAccBalance() {
  acc_addr="$1"

  echo "-> Getting balance for ${acc_addr}"
    ${CMD_Q} bank balances "${acc_addr}" -o json | pbcopy
  echo
}

# Transfer $3 coins via x/bank from $1 to $2 account address.
## Set $NEXT_TX_GAS (optionally $NEXT_TX_FEES) to override default gas usage.
function TransferCoins() {
  def_gas=100000
  from_addr="$1"
  to_addr="$2"
  amount="$3"

  echo "-> Transferring ${amount} from ${from_addr} to ${to_addr}"
    setNextTxGasAndFees ${def_gas}
    ${CMD_TX} bank send "${from_addr}" "${to_addr}" "${amount}" \
      --gas ${NEXT_TX_GAS} --fees "${NEXT_TX_FEES}" \
      --output json -y -b block | pbcopy
    checkTxFailed
    cleanLastTxGasAndFees
  echo
}

# --------- Contract initialisation ------------------------------------------------------------------------------------

# Upload WASM contract using $1 byteCode path sending from $2 account name.
## Sets: CONTRACT_CODE_ID.
## Set $NEXT_TX_GAS (optionally $NEXT_TX_FEES) to override default gas usage.
function UploadCodeAndGetID() {
  def_gas=5000000
  bytecode_path="$1"
  sender_name="$2"

  echo "-> Uploading code from ${sender_name}: ${bytecode_path}"
    setNextTxGasAndFees ${def_gas}
    ${CMD_TX} wasm store "${bytecode_path}" \
      --from "${sender_name}" \
      --gas ${NEXT_TX_GAS} --fees "${NEXT_TX_FEES}" \
      --output json -y -b block | pbcopy
    checkTxFailed
    cleanLastTxGasAndFees

    CONTRACT_CODE_ID=$(pbpaste | jq -r '.logs[0].events[] | select(.type=="store_code") | .attributes[0].value')

    echo "CodeID: ${CONTRACT_CODE_ID}"
  echo
}

# Instantiate WASM code from $3 account name using $1 message and $2 contract label defining the admin address.
## Uses: CONTRACT_CODE_ID.
## Sets: CONTRACT_ADDRESS.
## Set $NEXT_TX_GAS (optionally $NEXT_TX_FEES) to override default gas usage.
function InstantiateCodeWithAdmin() {
  def_gas=2000000
  msg="$1"
  label="$2"
  sender_name="$3"

  admin_addr=$(PrintAccountAddress "${sender_name}")

  echo "-> Instantiating codeID ${CONTRACT_CODE_ID} (${label}) from ${sender_name} with admin: ${admin_addr}"
    printf "Msg:\n%s\n" "$(echo "${msg}" | jq)"

    setNextTxGasAndFees ${def_gas}
    ${CMD_TX} wasm instantiate "${CONTRACT_CODE_ID}" "${msg}" \
      --label "${label}" \
      --admin "${admin_addr}" \
      --from "${sender_name}" \
      --gas ${NEXT_TX_GAS} --fees "${NEXT_TX_FEES}" \
      --output json -y -b block | pbcopy
    checkTxFailed
    cleanLastTxGasAndFees

    CONTRACT_ADDRESS=$(pbpaste | jq -r '.logs[0].events[] | select(.type=="instantiate") | .attributes[] | select(.key=="_contract_address").value')

    echo "ContractAddress: ${CONTRACT_ADDRESS}"
  echo
}

# Instantiate WASM code from $3 account name using $1 message and $2 contract label without admin set.
## Uses: CONTRACT_CODE_ID.
## Sets: CONTRACT_ADDRESS.
## Set $NEXT_TX_GAS (optionally $NEXT_TX_FEES) to override default gas usage.
function InstantiateCode() {
  def_gas=2000000
  msg="$1"
  label="$2"
  sender_name="$3"

  echo "-> Instantiating codeID ${CONTRACT_CODE_ID} (${label}) from ${sender_name} without admin"
    printf "Msg:\n%s\n" "$(echo "${msg}" | jq)"

    setNextTxGasAndFees ${def_gas}
    ${CMD_TX} wasm instantiate "${CONTRACT_CODE_ID}" "${msg}" \
      --label "${label}" \
      --no-admin \
      --from "${sender_name}" \
      --gas ${NEXT_TX_GAS} --fees "${NEXT_TX_FEES}" \
      --output json -y -b block | pbcopy
    checkTxFailed
    cleanLastTxGasAndFees

    CONTRACT_ADDRESS=$(pbpaste | jq -r '.logs[0].events[] | select(.type=="instantiate") | .attributes[] | select(.key=="_contract_address").value')

    echo "ContractAddress: ${CONTRACT_ADDRESS}"
  echo
}

# Set contract metadata updating $1 contract owner name and $2 rewards account name from $3 account name.
## Uses: CONTRACT_ADDRESS.
## Set $NEXT_TX_GAS (optionally $NEXT_TX_FEES) to override default gas usage.
function SetContractMetadata() {
  def_gas=100000
  owner_name="$1"
  rewards_name="$2"
  sender_name="$3"

  owner_addr=$(PrintAccountAddress "${owner_name}")
  rewards_addr=$(PrintAccountAddress "${rewards_name}")

  echo "-> Setting contract metadata from ${sender_name}: ownerName ${owner_name}, rewardsName ${rewards_name}"
    setNextTxGasAndFees ${def_gas}
    ${CMD_TX} rewards set-contract-metadata "${CONTRACT_ADDRESS}" \
      --owner-address "${owner_addr}" \
      --rewards-address "${rewards_addr}" \
      --from "${sender_name}" \
      --gas ${NEXT_TX_GAS} --fees "${NEXT_TX_FEES}" \
      --output json -y -b block | pbcopy
    checkTxFailed
    cleanLastTxGasAndFees

    echo "OwnerAddress: ${owner_addr}"
    echo "RewardsAddress: ${rewards_addr}"
  echo
}

# --------- Contract operations ----------------------------------------------------------------------------------------

# Select the latest codeID and contractAddress for $1 sender account name.
## Sets: CONTRACT_CODE_ID, CONTRACT_ADDRESS.
function SelectLatestCodeInstance() {
  sender_name="$1"

  sender_addr=$(PrintAccountAddress "${sender_name}")

  echo "-> Getting the latest contractAddress for ${sender_name}"
    ${CMD_Q} wasm list-code --output json | pbcopy

    CONTRACT_CODE_ID=$(pbpaste | jq -r '.code_infos[] | select(.creator=="'"${sender_addr}"'") | .code_id' | sort -n | tail -1)

    ${CMD_Q} wasm list-contract-by-code "${CONTRACT_CODE_ID}" --output json | pbcopy

    CONTRACT_ADDRESS=$(pbpaste | jq -r '.contracts[]' | tail -1)

    echo "Latest codeID: ${CONTRACT_CODE_ID}"
    echo "Latest contractAddress: ${CONTRACT_ADDRESS}"
  echo
}

# Send contract Execute $1 message from $2 account name.
## Uses: CONTRACT_ADDRESS, ESTIMATED_FEES.
## Set $NEXT_TX_GAS (optionally $NEXT_TX_FEES) to override default gas usage.
function SendContractExecuteMsg() {
  def_gas=1000000
  msg="$1"
  sender_name="$2"

  sender_addr=$(PrintAccountAddress "${sender_name}")

  echo "-> Sending Execute msg from ${sender_name}"
    printf "Msg:\n%s\n" "$(echo "${msg}" | jq)"

    setNextTxGasAndFees ${def_gas}
    ${CMD_TX} wasm execute "${CONTRACT_ADDRESS}" "${msg}" \
      --from "${sender_addr}" \
      --gas ${NEXT_TX_GAS} --fees "${NEXT_TX_FEES}" \
      --output json -y -b block | pbcopy
    checkTxFailed
    cleanLastTxGasAndFees
  echo
}

# Send contract Execute $1 message with $2 coins amount attached (default denom is used) from $3 account name.
## Uses: CONTRACT_ADDRESS, ESTIMATED_FEES.
## Set $NEXT_TX_GAS (optionally $NEXT_TX_FEES) to override default gas usage.
function SendContractExecuteMsgWithAmount() {
  def_gas=1000000
  msg="$1"
  amount="$2"
  sender_name="$3"

  sender_addr=$(PrintAccountAddress "${sender_name}")
  amount="${amount}${STAKE_DENOM}"

  echo "-> Sending Execute msg from ${sender_name} with ${amount} coins"
    printf "Msg:\n%s\n" "$(echo "${msg}" | jq)"

    setNextTxGasAndFees ${def_gas}
    ${CMD_TX} wasm execute "${CONTRACT_ADDRESS}" "${msg}" \
      --from "${sender_addr}" \
      --amount "${amount}" \
      --gas ${NEXT_TX_GAS} --fees "${NEXT_TX_FEES}" \
      --output json -y -b block | pbcopy
    checkTxFailed
    cleanLastTxGasAndFees
  echo
}

# Query contract using $1 query message using SMART query.
## Uses: CONTRACT_ADDRESS.
function QueryContractSmart() {
  query="$1"

  echo "-> Smart querying contract state"
    printf "Query:\n%s\n" "$(echo "${query}" | jq)"
    ${CMD_Q} wasm contract-state smart "${CONTRACT_ADDRESS}" "${query}" -o json | pbcopy
  echo
}

# Get contract metadata.
## Uses: CONTRACT_ADDRESS.
function GetMetadata() {
  echo "-> Querying metadata"
    ${CMD_Q} rewards contract-metadata "${CONTRACT_ADDRESS}" -o json | pbcopy
  echo
}

# Propose and vote for $1 contract Sudo message proposal with $2 title and $3 description.
# Proposal is send from the 1st validator.
## Uses: CONTRACT_ADDRESS.
## Set $DEF_GOV_DEPOSIT to override default deposit amount.
## Set $NEXT_TX_GAS (optionally $NEXT_TX_FEES) to override default gas usage.
function SubmitSudoProposal() {
  def_gas=1000000
  msg="$1"
  title="$2"
  desc="$3"

  sender_name="${ACCPREFIX_VALIDATOR}1"

  echo "-> Sending Sudo proposal (${title}, ${desc}) from ${sender_name}"
    printf "Proposal:\n%s\n" "$(echo "${msg}" | jq)"

    setNextTxGasAndFees ${def_gas}
    ${CMD_TX} gov submit-proposal sudo-contract "${CONTRACT_ADDRESS}" "${msg}" \
      --title "${title}" \
      --description "${desc}" \
      --deposit "${DEF_GOV_DEPOSIT}" \
      --from "${sender_name}" \
      --gas ${NEXT_TX_GAS} --fees "${NEXT_TX_FEES}" \
      --output json -y -b block | pbcopy
    checkTxFailed
    cleanLastTxGasAndFees

    proposal_id=$(pbpaste | jq -r '.logs[0].events[] | select(.type=="submit_proposal").attributes[] | select(.key=="proposal_id").value')

    echo "ProposalID: ${proposal_id}"
  echo

  VoteForProposal "${proposal_id}"
}

# Print contract query results.
function PrintQueryResults() {
    echo "-> Printing query results"
      pbpaste | jq '.data'
    echo
}

# Print contract info fron x/wasm.
function PrintContractInfo() {
  echo "-> Printing contract info"
    ${CMD_Q} wasm contract "${CONTRACT_ADDRESS}" -o json | jq
  echo
}

# ---------- Transaction operations ------------------------------------------------------------------------------------

# Print the latest tx / query output (which might be pbcopy-ed) as JSON.
function PrintLatestOutput() {
    pbpaste | jq
}

# Print tx raw log.
function PrintTxRawLog() {
  echo "-> Printing TX raw log"
    pbpaste | jq '.raw_log'
  echo
}

# Print tx data HEX decoded.
function PrintTxData() {
  echo "-> Printing TX data"
    pbpaste | jq -r '.data' | xxd -r -p
  echo
}

# Prints next transaction fees by $1 gas limit.
function PrintNextTxFeesEstimation() {
  gas_limit="$1"

  ${CMD_Q} rewards estimate-fees ${gas_limit} -o json | pbcopy

  denom=$(pbpaste | jq -r '.estimated_fee.denom')
  amount=$(pbpaste | jq -r '.estimated_fee.amount')

  echo "${amount}${denom}"
}

# Vote for $1 proposalID from all cluster validators.
function VoteForProposal() {
  def_gas=100000
  proposal_id="$1"

  echo "-> Proposal ${proposal_id} voting"
    for i in $(seq 1 ${NODES_CNT}); do
      sender_name="${ACCPREFIX_VALIDATOR}${i}"
      echo "Sending vote: ${sender_name}"

      setNextTxGasAndFees ${def_gas}
      ${CMD_TX} gov vote "${proposal_id}" yes \
        --from "${sender_name}" \
        --gas ${NEXT_TX_GAS} --fees "${NEXT_TX_FEES}" \
        --output json -y -b block | pbcopy
      checkTxFailed
      cleanLastTxGasAndFees
    done
  echo

  echo "-> Wait for voting period to end"
    i=0
    while true; do
      sleep 5
      ((i=i+5))

      proposal_status=$(${CMD_Q} gov proposal "${proposal_id}" -o json | jq -r '.status')
      echo "${i}: current status: ${proposal_status}"

      if [ "${proposal_status}" = "PROPOSAL_STATUS_PASSED" ]; then
        break
      fi

      if [ "${proposal_status}" = "PROPOSAL_STATUS_REJECTED" ]; then
        echo "Proposal ${proposal_id} rejected"
        exit 1
      fi
    done
  echo
}

# ---------- Common operations -----------------------------------------------------------------------------------------

# Print current block height.
function PrintBlockHeight() {
  ${CMD_Q} block | jq -r '.block.header.height'
}

# Print account address by $1 account name.
function PrintAccountAddress() {
  acc_name="$1"

  ${CMD_KEYS} show -a "${acc_name}"
}

# Print gas tracking info for the last 10 blocks.
function PrintGasRewardsTrackingHistory() {
  cur_block=$(PrintBlockHeight)

  echo "-> Current block: ${cur_block}"
  echo

  for i in {1..10}; do
    echo "-> Gas / rewards tracking for block: ${cur_block}"
    ${CMD_Q} tracking block-gas-tracking --height ${cur_block} -o json | jq
    ${CMD_Q} rewards block-rewards-tracking --height ${cur_block} -o json | jq
    echo

    cur_block=$((cur_block-1))
  done
}

# Print open IBC channels in compact form.
function PrintOpenIBCChannels() {
  echo "-> Open IBC channels"
    ${CMD_Q} ibc channel channels -o json | pbcopy
    pbpaste | jq '.channels[] | select(.state == "STATE_OPEN") | {ChannelID: .channel_id, PortID: .port_id, Order: .ordering, Version: .version, Counterparty: { ChannelID: .counterparty.channel_id, PortID: .counterparty.port_id }}'
  echo
}

# ---------- Internal --------------------------------------------------------------------------------------------------

# Set the next tx gas limit and fees.
# If the $NEXT_TX_GAS is set, use that, otherwise use $1.
# If the $NEXT_TX_FEES is set, use that, otherwise estimate tx fees.
function setNextTxGasAndFees() {
  def_gas="$1"

  if [ -z "${NEXT_TX_GAS}" ]; then
    NEXT_TX_GAS=${def_gas}
    echo "Using default gas: ${def_gas}"
  else
    echo "Using custom gas: ${NEXT_TX_GAS}"
  fi

  if [ -z "${NEXT_TX_FEES}" ]; then
    NEXT_TX_FEES=$(PrintNextTxFeesEstimation "${NEXT_TX_GAS}")
    echo "Using estimated fees: ${NEXT_TX_FEES}"
  else
    echo "Using custom fees: ${NEXT_TX_FEES}"
  fi
}

# Cleans up the $NEXT_TX_GAS and the $NEXT_TX_FEES values.
function cleanLastTxGasAndFees() {
  NEXT_TX_GAS=""
  NEXT_TX_FEES=""
}

# Check if the last transaction has failed.
function checkTxFailed() {
    codespace="$(pbpaste | jq -r '.codespace')"
    code="$(pbpaste | jq -r '.code')"
    tx_hash="$(pbpaste | jq -r '.txhash')"

    echo "TxHash: ${tx_hash}"
    if [ -n "${codespace}" ] || [ "${code}" != "0" ]; then
      echo "-> Transaction failed"
      PrintTxRawLog
      exit 1
    fi
}