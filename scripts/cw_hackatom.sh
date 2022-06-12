#!/bin/bash

set -e

# Input
VERIFIER_NAME="arch-1_local-bank"
BENEFICIARY_NAME="arch-1_faucet-1"

CONTRACT_BYTECODE_PATH="${HOME}/Go_Projects/src/github.com/CosmWasm/cosmwasm-go/example/hackatom/hackatom.wasm"
CONTRACT_LABEL="hackatom"

CMD_KEYS="archwayd keys --keyring-backend os"
CMD_TX="archwayd tx --chain-id arch-1 --node tcp://localhost:26671 --keyring-backend os"
CMD_Q="archwayd q --node tcp://localhost:26671"

GAS=2000000
#

# State
VERIFIER_ADDR=""
BENEFICIARY_ADDR=""

CODE_ID=""
CONTRACT_ADDR=""
#

# Templates
MSG_INSTANTIATE='{ "verifier": "%verifierAddr%", "beneficiary": "%beneficiaryAddr%" }'
MSG_RELEASE='{ "release": {} }'

QUERY_VERIFIER='{ "verifier": {} }'
QUERY_OTHER_BALANCE='{ "other_balance": { "address": "%addr%" } }'
#

# Get account address
function SetUsersAddress() {
  echo "-> Reading account addresses"
    VERIFIER_ADDR=$(${CMD_KEYS} show -a ${VERIFIER_NAME})
    BENEFICIARY_ADDR=$(${CMD_KEYS} show -a ${BENEFICIARY_NAME})
    echo "Verifier addr (${VERIFIER_NAME}): ${VERIFIER_ADDR}"
    echo "Beneficiary addr (${BENEFICIARY_NAME}): ${BENEFICIARY_ADDR}"
  echo
}

# Upload and get codeID
function UploadCodeAndGetID() {
  echo "-> Uploading code for the Verifier addr"
    ${CMD_TX} wasm store "${CONTRACT_BYTECODE_PATH}" --from "${VERIFIER_ADDR}" --gas ${GAS} --output json -y -b block | pbcopy
    CODE_ID=$(pbpaste | jq -r '.logs[0].events[] | select(.type=="store_code") | .attributes[0].value')
    echo "CodeID: ${CODE_ID}"
  echo
}

# Instantiate and get contractAddress
function InstantiateAndGetAddress() {
  msg="${MSG_INSTANTIATE//%verifierAddr%/$VERIFIER_ADDR}"
  msg="${msg//%beneficiaryAddr%/$BENEFICIARY_ADDR}"

  echo "-> Instantiating code (${CODE_ID}) from the Verifier addr"
    printf "Msg:\n%s\n" "$(echo "${msg}" | jq)"
    ${CMD_TX} wasm instantiate "${CODE_ID}" "${msg}" --label "${CONTRACT_LABEL}" --no-admin --from "${VERIFIER_ADDR}" --output json --gas ${GAS} -y -b block | pbcopy
    CONTRACT_ADDR=$(pbpaste | jq -r '.logs[0].events[] | select(.type=="instantiate") | .attributes[] | select(.key=="_contract_address").value')
    echo "ContractAddress: ${CONTRACT_ADDR}"
  echo
}

# Get the latest uploaded codeID and instanceID
function SelectLatestCodeInstance() {
  echo "-> Getting the latest contractAddress for the Verifier addr"
    ${CMD_Q} wasm list-code --output json | pbcopy
    CODE_ID=$(pbpaste | jq -r '.code_infos[] | select(.creator=="'"${VERIFIER_ADDR}"'") | .code_id' | sort -n | tail -1)
    echo "Latest codeID: ${CODE_ID}"

    ${CMD_Q} wasm list-contract-by-code "${CODE_ID}" --output json | pbcopy
    CONTRACT_ADDR=$(pbpaste | jq -r '.contracts[]' | tail -1)
    echo "Latest contractAddress: ${CONTRACT_ADDR}"
  echo
}

# Get an account balance
function GetAccBalance() {
  acc_addr="$1"

  echo "-> Getting account (${acc_addr}) balance"
    ${CMD_Q} bank balances "${acc_addr}" -o json | jq
  echo
}

# Transfer coins via x/bank
function TransferCoins() {
  from_addr="$1"
  to_addr="$2"
  coins="$3"

  echo "-> Transferring (${coins}) from (${from_addr}) to (${to_addr})"
    ${CMD_TX} bank send "${from_addr}" "${to_addr}" "${coins}" --from "${from_addr}" -y -b block | pbcopy
  echo
}

# Send Release message
function MsgRelease() {
  msg="${MSG_RELEASE}"

  echo "-> Sending Release msg from the Verifier addr (releasing to the Beneficiary addr)"
    printf "Msg:\n%s\n" "$(echo "${msg}" | jq)"
    ${CMD_TX} wasm execute "${CONTRACT_ADDR}" "${msg}" --from "${VERIFIER_ADDR}" --gas ${GAS} -y -b block
  echo
}

# Send custom message
function MsgCustom() {
  msg="$1"

  echo "-> Sending a custom msg from the Verifier addr"
    printf "Msg:\n%s\n" "$(echo "${msg}" | jq)"
    ${CMD_TX} wasm execute "${CONTRACT_ADDR}" "${msg}" --from "${VERIFIER_ADDR}" --gas ${GAS} -y -b block
  echo
}

# Query Verifier endpoint
function QueryVerifier() {
  query="${QUERY_VERIFIER}"

  echo "-> Querying the Verifier endpoint"
    printf "Query:\n%s\n" "$(echo "${query}" | jq)"
    ${CMD_Q} wasm contract-state smart "${CONTRACT_ADDR}" "${query}"
  echo
}

# Query OtherBalance endpoint
function QueryOtherBalance() {
  addr="$1"

  query="${QUERY_OTHER_BALANCE}"
  query="${query//%addr%/$addr}"

  echo "-> Querying the OtherBalance endpoint with addr (${addr})"
    printf "Query:\n%s\n" "$(echo "${query}" | jq)"
    ${CMD_Q} wasm contract-state smart "${CONTRACT_ADDR}" "${query}"
  echo
}

# Query custom endpoint
function QueryCustom() {
  query="$1"

  echo "-> Querying a custom endpoint"
    printf "Query:\n%s\n" "$(echo "${query}" | jq)"
    ${CMD_Q} wasm contract-state smart "${CONTRACT_ADDR}" "${query}"
  echo
}

# Main
SetUsersAddress

while [[ $# -gt 0 ]]; do
  case $1 in
  init)
    shift

    UploadCodeAndGetID
    InstantiateAndGetAddress
    ;;
  balance-contract)
    shift

    SelectLatestCodeInstance
    GetAccBalance "${CONTRACT_ADDR}"
    ;;
  balance-beneficiary)
    shift

    GetAccBalance "${BENEFICIARY_ADDR}"
    ;;
  fund-contract)
    shift
    if [ $# != 1 ]; then
      echo "Usage: fund-contract {amount}"
      exit 1
    fi
    coins="$1"; shift

    SelectLatestCodeInstance
    TransferCoins "${VERIFIER_ADDR}" "${CONTRACT_ADDR}" "${coins}"
    ;;
  msg-release)
    shift

    SelectLatestCodeInstance
    MsgRelease
    ;;
  msg-custom)
    shift
    if [ $# != 1 ]; then
      echo "Usage: msg-custom {msg}"
      exit 1
    fi
    msg="$1"; shift

    SelectLatestCodeInstance
    MsgCustom "${msg}"
    ;;
  query-verifier)
    shift

    SelectLatestCodeInstance
    QueryVerifier
    ;;
  query-otherBalance)
    shift
    if [ $# != 1 ]; then
      echo "Usage: query-otherBalance {addr}"
      exit 1
    fi
    addr="$1"; shift

    SelectLatestCodeInstance
    QueryOtherBalance "${addr}"
    ;;
  query-custom)
    shift
    if [ $# != 1 ]; then
      echo "Usage: query-custom {query}"
      exit 1
    fi
    query="$1"; shift

    SelectLatestCodeInstance
    QueryCustom "${query}"
    ;;
  *)
    echo "Unsupported cmd"
    exit 1
    ;;
  esac
done
