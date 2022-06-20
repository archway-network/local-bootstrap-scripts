#!/bin/bash

set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source "$(dirname ${DIR})/lib/utils.sh"

# Input
CREATOR_NAME="arch-1_local-bank"
VOTER1_NAME="arch-1_local-validator-1"
VOTER2_NAME="arch-1_local-validator-2"
VOTER3_NAME="arch-1_local-validator-3"

CONTRACT_BYTECODE_PATH="${HOME}/Go_Projects/src/github.com/CosmWasm/cosmwasm-go/example/voter/voter.wasm"
CONTRACT_LABEL="voter"

CMD_KEYS="archwayd keys --keyring-backend os"
CMD_TX="archwayd tx --chain-id arch-1 --node tcp://localhost:26671 --keyring-backend os"
CMD_Q="archwayd q --node tcp://localhost:26671"

GAS=2000000
DENOM="stake"

NEWVOTING_COST_AMT="1000"
VOTE_COST_AMT="100"

NEWVOTING_COST_SUDO_AMT="999"
VOTE_COST_SUDO_AMT="99"
GOV_DEPOSIT="10000000${DENOM}"
#

# State
CREATOR_ADDR=""
VOTER1_ADDR=""
VOTER2_ADDR=""
VOTER3_ADDR=""

CODE_ID=""
CONTRACT_ADDR=""
#

# Templates
MSG_INSTANTIATE='{ "params": { "owner_addr": "%ownerAddr%", "new_voting_cost": { "denom": "%denom%", "amount": "%newVotingAmt%" }, "vote_cost": { "denom": "%denom%", "amount": "%voteAmt%" } } }'
MSG_RELEASE='{ "release": {} }'
MSG_NEW_VOTING='{ "new_voting": { "name": "%name%", "vote_options": [ %voteOptions% ], "duration": %duration% } }'
MSG_VOTE='{ "vote": { "id": %id%, "option": "%option%", "vote": "%vote%" } }'

QUERY_PARAMS='{ "params": {} }'
QUERY_VOTING='{ "voting": { "id": %id% } }'
QUERY_TALLY='{ "tally": { "id": %id% } }'
QUERY_OPEN='{ "open": {} }'
QUERY_RELEASE_STATS='{ "release_stats": {} }'

SUDO_CHANGE_NEWVOTING_COST='{ "change_new_voting_cost": { "new_cost": { "denom": "%denom%", "amount": "%amount%" } } }'
SUDO_CHANGE_VOTE_COST='{ "change_vote_cost": { "new_cost": { "denom": "%denom%", "amount": "%amount%" } } }'
#

# Get account address
function SetUsersAddress() {
  echo "-> Reading account addresses"
    CREATOR_ADDR=$(${CMD_KEYS} show -a "${CREATOR_NAME}")
    VOTER1_ADDR=$(${CMD_KEYS} show -a "${VOTER1_NAME}")
    VOTER2_ADDR=$(${CMD_KEYS} show -a "${VOTER2_NAME}")
    VOTER3_ADDR=$(${CMD_KEYS} show -a "${VOTER3_NAME}")
    echo "Sender addr (${CREATOR_NAME}): ${CREATOR_ADDR}"
    echo "Voter 1 addr (${VOTER1_NAME}): ${VOTER1_ADDR}"
    echo "Voter 2 addr (${VOTER2_NAME}): ${VOTER2_ADDR}"
    echo "Voter 3 addr (${VOTER3_NAME}): ${VOTER3_ADDR}"
  echo
}

# Upload and get codeID
function UploadCodeAndGetID() {
  echo "-> Uploading code for the Sender addr"
    ${CMD_TX} wasm store "${CONTRACT_BYTECODE_PATH}" --from "${CREATOR_ADDR}" --gas ${GAS} --output json -y -b block | pbcopy
    CODE_ID=$(pbpaste | jq -r '.logs[0].events[] | select(.type=="store_code") | .attributes[0].value')
    echo "CodeID: ${CODE_ID}"
  echo
}

# Instantiate and get contractAddress
function InstantiateAndGetAddress() {
  owner_addr="$1"

  msg="${MSG_INSTANTIATE//%ownerAddr%/$owner_addr}"
  msg="${msg//%denom%/$DENOM}"
  msg="${msg//%newVotingAmt%/$NEWVOTING_COST_AMT}"
  msg="${msg//%voteAmt%/$VOTE_COST_AMT}"

  echo "-> Instantiating code (${CODE_ID}) from the Sender addr"
    printf "Msg:\n%s\n" "$(echo "${msg}" | jq)"
    ${CMD_TX} wasm instantiate "${CODE_ID}" "${msg}" --label "${CONTRACT_LABEL}" --no-admin --from "${CREATOR_ADDR}" --output json --gas ${GAS} -y -b block | pbcopy

    CONTRACT_ADDR=$(pbpaste | jq -r '.logs[0].events[] | select(.type=="instantiate") | .attributes[] | select(.key=="_contract_address").value')
    echo "ContractAddress: ${CONTRACT_ADDR}"
  echo
}

# Get the latest uploaded codeID and instanceID
function SelectLatestCodeInstance() {
  echo "-> Getting the latest contractAddress for the Sender addr"
    ${CMD_Q} wasm list-code --output json | pbcopy
    CODE_ID=$(pbpaste | jq -r '.code_infos[] | select(.creator=="'"${CREATOR_ADDR}"'") | .code_id' | sort -n | tail -1)
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
    ${CMD_TX} bank send "${from_addr}" "${to_addr}" "${coins}" --from "${from_addr}" -y -b block -o json | pbcopy
  echo
}

# Release contract funds
function MsgRelease() {
  sender="$1"

  msg=${MSG_RELEASE}

  echo "-> Sending the Release msg from the (${sender}) addr"
    printf "Msg:\n%s\n" "$(echo "${msg}" | jq)"
    ${CMD_TX} wasm execute "${CONTRACT_ADDR}" "${msg}" --from "${sender}" --gas ${GAS} -y -b block -o json | pbcopy

    pbpaste | jq -r '.data' | xxd -r -p; echo
    pbpaste | jq '.raw_log'
  echo
}

# Create new voting
function MsgNewVoting() {
  name="$1"
  opts_raw="$2"
  dur="$3"

  # Split with ',' and double quote every value
  opts_array=(${opts_raw//,/ })
  for (( i=0; i<${#opts_array[@]}; i++ )); do
    opts_array[$i]="\"${opts_array[$i]}\""
  done
  opts=$(ArrayJoin ',' "${opts_array[@]}")

  msg=${MSG_NEW_VOTING//%name%/$name}
  msg=${msg//%voteOptions%/$opts}
  msg=${msg//%duration%/$dur}

  amount="${NEWVOTING_COST_AMT}${DENOM}"

  echo "-> Sending the NewVoting msg from the Sender addr with amount (${amount})"
    printf "Msg:\n%s\n" "$(echo "${msg}" | jq)"
    ${CMD_TX} wasm execute "${CONTRACT_ADDR}" "${msg}" --amount "${amount}" --from "${CREATOR_ADDR}" --gas ${GAS} -y -b block -o json | pbcopy

    VOTING_ID=$(pbpaste | jq -r '.logs[0].events[] | select(.type=="wasm-new_voting") | .attributes[] | select(.key=="voting_id").value')
    echo "Voting ID: ${VOTING_ID}"
  echo
}

# Vote
function MsgVote() {
  sender="$1"
  id="$2"
  option="$3"
  vote="$4"

  msg=${MSG_VOTE//%id%/$id}
  msg=${msg//%option%/$option}
  msg=${msg//%vote%/$vote}

  amount="${VOTE_COST_AMT}${DENOM}"

  echo "-> Sending the Vote msg from the (${sender}) addr with amount (${amount})"
    printf "Msg:\n%s\n" "$(echo "${msg}" | jq)"
    ${CMD_TX} wasm execute "${CONTRACT_ADDR}" "${msg}" --amount "${amount}" --from "${sender}" --gas ${GAS} -y -b block -o json | pbcopy

    pbpaste | jq '.raw_log'
  echo
}

# Send custom message
function MsgCustom() {
  msg="$1"

  echo "-> Sending a custom msg from the Verifier addr"
    printf "Msg:\n%s\n" "$(echo "${msg}" | jq)"
    ${CMD_TX} wasm execute "${CONTRACT_ADDR}" "${msg}" --from "${CREATOR_ADDR}" --gas ${GAS} -y -b block
  echo
}

# Query Params endpoint
function QueryParams() {
  query="${QUERY_PARAMS}"

  echo "-> Querying the Params endpoint"
    printf "Query:\n%s\n" "$(echo "${query}" | jq)"
    ${CMD_Q} wasm contract-state smart "${CONTRACT_ADDR}" "${query}" -o json | pbcopy

    echo; echo "Response:"
    pbpaste | jq '.data'
  echo
}

# Query Voting endpoint
function QueryVoting() {
  id="$1"

  query=${QUERY_VOTING//%id%/$id}

  echo "-> Querying the Voting endpoint"
    printf "Query:\n%s\n" "$(echo "${query}" | jq)"
    ${CMD_Q} wasm contract-state smart "${CONTRACT_ADDR}" "${query}" -o json | pbcopy

    echo; echo "Response:"
    pbpaste | jq '.data'
  echo
}

# Query Tally endpoint
function QueryTally() {
  id="$1"

  query=${QUERY_TALLY//%id%/$id}

  echo "-> Querying the Tally endpoint"
    printf "Query:\n%s\n" "$(echo "${query}" | jq)"
    ${CMD_Q} wasm contract-state smart "${CONTRACT_ADDR}" "${query}" -o json | pbcopy

    echo; echo "Response:"
    pbpaste | jq '.data'
  echo
}

# Query Open endpoint
function QueryOpen() {
  query=${QUERY_OPEN}

  echo "-> Querying the Tally endpoint"
    printf "Query:\n%s\n" "$(echo "${query}" | jq)"
    ${CMD_Q} wasm contract-state smart "${CONTRACT_ADDR}" "${query}" -o json | pbcopy

    echo; echo "Response:"
    pbpaste | jq '.data'
  echo
}

# Query ReleaseStats endpoint
function QueryReleaseStats() {
  query=${QUERY_RELEASE_STATS}

  echo "-> Querying the ReleaseStats endpoint"
    printf "Query:\n%s\n" "$(echo "${query}" | jq)"
    ${CMD_Q} wasm contract-state smart "${CONTRACT_ADDR}" "${query}" -o json | pbcopy

    echo; echo "Response:"
    pbpaste | jq '.data'
  echo
}

# Query custom endpoint
function QueryCustom() {
  query="$1"

  echo "-> Querying a custom endpoint"
    printf "Query:\n%s\n" "$(echo "${query}" | jq)"
    ${CMD_Q} wasm contract-state smart "${CONTRACT_ADDR}" "${query}" -o json | pbcopy

    echo; echo "Response:"
    pbpaste | jq '.data'
  echo
}

# Propose and vote for the NewVotingCost sudo Gov proposal
function SudoNewVotingCost() {
  msg=${SUDO_CHANGE_NEWVOTING_COST//%denom%/$DENOM}
  msg=${msg//%amount%/$NEWVOTING_COST_SUDO_AMT}

  echo "-> Sending NewVotingCost proposal"
    printf "Proposal:\n%s\n" "$(echo "${msg}" | jq)"
    ${CMD_TX} gov submit-proposal sudo-contract "${CONTRACT_ADDR}" "${msg}" \
      --title "NewVoting cost change" \
      --description "Lower the cost just because" \
      --deposit "${GOV_DEPOSIT}" \
      --from "${CREATOR_ADDR}" \
      --gas ${GAS} \
      -y -b block \
      -o json | pbcopy

    proposal_id=$(pbpaste | jq -r '.logs[0].events[] | select(.type=="submit_proposal").attributes[] | select(.key=="proposal_id").value')
    echo "ProposalID: ${proposal_id}"
  echo

  voteForProposal "${proposal_id}"
}

# Propose and vote for the VoteCost sudo Gov proposal
function SudoVoteCost() {
  msg=${SUDO_CHANGE_VOTE_COST//%denom%/$DENOM}
  msg=${msg//%amount%/$VOTE_COST_SUDO_AMT}

  echo "-> Sending VoteCost proposal"
    printf "Proposal:\n%s\n" "$(echo "${msg}" | jq)"
    ${CMD_TX} gov submit-proposal sudo-contract "${CONTRACT_ADDR}" "${msg}" \
      --title "Vote cost change" \
      --description "Lower the cost just because" \
      --deposit "${GOV_DEPOSIT}" \
      --from "${CREATOR_ADDR}" \
      --gas ${GAS} \
      -y -b block \
      -o json | pbcopy

    proposal_id=$(pbpaste | jq -r '.logs[0].events[] | select(.type=="submit_proposal").attributes[] | select(.key=="proposal_id").value')
    echo "ProposalID: ${proposal_id}"
  echo

  voteForProposal "${proposal_id}"
}

function voteForProposal() {
  proposal_id="$1"

  echo "-> Vote with [${VOTER1_NAME}, ${VOTER2_NAME}, ${VOTER3_NAME}] accounts"
    ${CMD_TX} gov vote "${proposal_id}" yes --from "${VOTER1_ADDR}" -y -b block | pbcopy
    ${CMD_TX} gov vote "${proposal_id}" yes --from "${VOTER2_ADDR}" -y -b block | pbcopy
    ${CMD_TX} gov vote "${proposal_id}" yes --from "${VOTER3_ADDR}" -y -b block | pbcopy
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
    done
  echo
}

# Main
SetUsersAddress

while [[ $# -gt 0 ]]; do
  case $1 in
  init)
    shift

    UploadCodeAndGetID
    InstantiateAndGetAddress "${CREATOR_ADDR}"
    ;;
  balance-contract)
    shift

    SelectLatestCodeInstance
    GetAccBalance "${CONTRACT_ADDR}"
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
    MsgRelease "${CREATOR_ADDR}"
    ;;
  msg-new-voting)
    shift
    if [ $# != 3 ]; then
      echo "Usage: msg-new-voting {name} {commaSeparatedOptions} {votingDurationInNS}"
      exit 1
    fi
    name="$1"; shift
    opts="$1"; shift
    dur="$1"; shift

    SelectLatestCodeInstance
    MsgNewVoting "${name}" "${opts}" "${dur}"
    ;;
  msg-vote)
    shift
    if [ $# != 4 ]; then
      echo "Usage: msg-vote {voterID} {votingID} {option} {vote}"
      exit 1
    fi
    voter_id="$1"; shift
    voting_id="$1"; shift
    option="$1"; shift
    vote="$1"; shift

    voter_addr=""
    case $voter_id in
      1) voter_addr="${VOTER1_ADDR}";;
      2) voter_addr="${VOTER2_ADDR}";;
      3) voter_addr="${VOTER3_ADDR}";;
      *) echo "Unknown voterID (1/2/3 is expected)"; exit 1
    esac

    SelectLatestCodeInstance
    MsgVote "${voter_addr}" "${voting_id}" "${option}" "${vote}"
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
  query-params)
    shift

    SelectLatestCodeInstance
    QueryParams
    ;;
  query-voting)
    shift
    if [ $# != 1 ]; then
      echo "Usage: query-voting {votingID}"
      exit 1
    fi
    id="$1"; shift

    SelectLatestCodeInstance
    QueryVoting "${id}"
    ;;
  query-tally)
    shift
    if [ $# != 1 ]; then
      echo "Usage: query-tally {votingID}"
      exit 1
    fi
    id="$1"; shift

    SelectLatestCodeInstance
    QueryTally "${id}"
    ;;
  query-open)
    shift

    SelectLatestCodeInstance
    QueryOpen
    ;;
  query-release-stats)
    shift

    SelectLatestCodeInstance
    QueryReleaseStats
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
  sudo-newvoting-cost)
    shift

    SelectLatestCodeInstance
    SudoNewVotingCost
    ;;
  sudo-vote-cost)
    shift

    SelectLatestCodeInstance
    SudoVoteCost
    ;;
  *)
    echo "Unsupported cmd"
    exit 1
    ;;
  esac
done
