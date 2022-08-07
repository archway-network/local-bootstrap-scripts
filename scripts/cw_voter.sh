#!/bin/bash

set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
source "${DIR}/common.sh"
source "$(dirname ${DIR})/lib/utils.sh"

# Inputs
CHAIN_CONFIG="$(dirname ${DIR})/config/arch-1.sh" # chain config file path (can be altered with -c)
CONTRACT_OWNER_NAME_SUFFIX="local-bank"           # suffix of the contract owner name (refer to $CONTRACT_OWNER_NAME)
CONTRACT_BYTECODE_PATH="${HOME}/Go_Projects/src/github.com/CosmWasm/cosmwasm-go/example/voter/voter.wasm"

# State
CONTRACT_OWNER_NAME="" # contract owner name (set later as: "${CHAIN_ID}_${CONTRACT_OWNER_NAME_SUFFIX}")

# Defaults
CONTRACT_LABEL="voter"    # instantiation label
NEWVOTING_COST_AMT="1000" # voting creation cost
VOTE_COST_AMT="100"       # vote cost

NEWVOTING_COST_SUDO_AMT="999" # updated voting creation cost
VOTE_COST_SUDO_AMT="99"       # updated vote cost

# Templates
MSG_INSTANTIATE='{ "params": { "owner_addr": "%ownerAddr%", "new_voting_cost": "%newVotingAmt%%denom%", "vote_cost": "%voteAmt%%denom%", "ibc_send_timeout": 30000000000 } }'
MSG_RELEASE='{ "release": {} }'
MSG_NEW_VOTING='{ "new_voting": { "name": "%name%", "vote_options": [ %voteOptions% ], "duration": %duration% } }'
MSG_VOTE='{ "vote": { "id": %id%, "option": "%option%", "vote": "%vote%" } }'
MSG_VOTE_IBC='{ "send_ibc_vote": { "id": %id%, "option": "%option%", "vote": "%vote%", "channel_id": "%channelID%" } }'

QUERY_PARAMS='{ "params": {} }'
QUERY_VOTING='{ "voting": { "id": %id% } }'
QUERY_TALLY='{ "tally": { "id": %id% } }'
QUERY_OPEN='{ "open": {} }'
QUERY_RELEASE_STATS='{ "release_stats": {} }'

SUDO_CHANGE_NEWVOTING_COST='{ "change_new_voting_cost": { "new_cost": { "denom": "%denom%", "amount": "%amount%" } } }'
SUDO_CHANGE_VOTE_COST='{ "change_vote_cost": { "new_cost": { "denom": "%denom%", "amount": "%amount%" } } }'
#

# Main
function init() {
  SetupChainParams "${CHAIN_CONFIG}"
  CONTRACT_OWNER_NAME="${CHAIN_ID}_${CONTRACT_OWNER_NAME_SUFFIX}"
}
init

while [[ $# -gt 0 ]]; do
  case $1 in
  -c | --config)
    shift
    if [ $# -lt 1 ]; then
      echo "Usage: -c {alternativeChainConfig}"
      exit 1
    fi
    CHAIN_CONFIG="$1"; shift

    init
    ;;
  init)
    shift; echo ">> Initializing contract..."
    owner_addr=$(PrintAccountAddress ${CONTRACT_OWNER_NAME})

    msg="${MSG_INSTANTIATE//%ownerAddr%/$owner_addr}"
    msg="${msg//%denom%/$STAKE_DENOM}"
    msg="${msg//%newVotingAmt%/$NEWVOTING_COST_AMT}"
    msg="${msg//%voteAmt%/$VOTE_COST_AMT}"

    UploadCodeAndGetID "${CONTRACT_BYTECODE_PATH}" "${CONTRACT_OWNER_NAME}"
    InstantiateCodeWithAdmin "${msg}" "${CONTRACT_LABEL}" "${CONTRACT_OWNER_NAME}"
    SetContractMetadata "${CONTRACT_OWNER_NAME}" "${CONTRACT_OWNER_NAME}" "${CONTRACT_OWNER_NAME}"
    ;;
  info)
    shift; echo ">> Print contract and chain info..."

    SelectLatestCodeInstance "${CONTRACT_OWNER_NAME}"
    PrintContractInfo
    PrintOpenIBCChannels
    ;;
  balance-contract)
    shift; echo ">> Getting contract balance..."

    SelectLatestCodeInstance "${CONTRACT_OWNER_NAME}"
    GetAccBalance "${CONTRACT_ADDRESS}"
    PrintLatestOutput
    ;;
  balance-owner)
    shift; echo ">> Getting owner (rewardsAddr) balance..."

    owner_addr=$(PrintAccountAddress ${CONTRACT_OWNER_NAME})

    GetAccBalance "${owner_addr}"
    PrintLatestOutput
    ;;
  release)
    shift; echo ">> Releasing contract funds to its owner..."

    msg=${MSG_RELEASE}

    SelectLatestCodeInstance "${CONTRACT_OWNER_NAME}"
    SendContractExecuteMsg "${msg}" "${CONTRACT_OWNER_NAME}"
    ;;
  new-voting)
    shift; echo ">> Creating a new voting..."
    if [ $# != 3 ]; then
      echo "Usage: {votingName} {commaSeparatedOptions} {votingDurationInNS}"
      exit 1
    fi
    name="$1"; shift
    opts_raw="$1"; shift
    dur="$1"; shift

    # Split with ',' and double quote every value
    opts_array=(${opts_raw//,/ })
    for ((i = 0; i < ${#opts_array[@]}; i++)); do
      opts_array[$i]="\"${opts_array[$i]}\""
    done
    opts=$(ArrayJoin ',' "${opts_array[@]}")

    msg=${MSG_NEW_VOTING//%name%/$name}
    msg=${msg//%voteOptions%/$opts}
    msg=${msg//%duration%/$dur}

    SelectLatestCodeInstance "${CONTRACT_OWNER_NAME}"
    SendContractExecuteMsgWithAmount "${msg}" "${NEWVOTING_COST_AMT}" "${CONTRACT_OWNER_NAME}"

    voting_id=$(pbpaste | jq -r '.logs[0].events[] | select(.type=="wasm-new_voting") | .attributes[] | select(.key=="voting_id").value')
    echo "Voting ID: ${voting_id}"
    ;;
  vote)
    shift; echo ">> Adding a vote..."
    if [ $# != 4 ]; then
      echo "Usage: {voterName} {votingID} {option} {vote}"
      exit 1
    fi
    voter_name="$1"; shift
    voting_id="$1"; shift
    option="$1"; shift
    vote="$1"; shift

    msg=${MSG_VOTE//%id%/$voting_id}
    msg=${msg//%option%/$option}
    msg=${msg//%vote%/$vote}

    SelectLatestCodeInstance "${CONTRACT_OWNER_NAME}"
    SendContractExecuteMsgWithAmount "${msg}" "${VOTE_COST_AMT}" "${voter_name}"
    ;;
  vote-ibc)
    shift; echo ">> Adding a vote via IBC..."
    if [ $# != 5 ]; then
      echo "Usage: {voterName} {votingID} {option} {vote} {ibcChannelID}"
      exit 1
    fi
    voter_name="$1"; shift
    voting_id="$1"; shift
    option="$1"; shift
    vote="$1"; shift
    channel_id="$1"; shift

    msg=${MSG_VOTE_IBC//%id%/$voting_id}
    msg=${msg//%option%/$option}
    msg=${msg//%vote%/$vote}
    msg=${msg//%channelID%/$channel_id}

    SelectLatestCodeInstance "${CONTRACT_OWNER_NAME}"
    SendContractExecuteMsgWithAmount "${msg}" "${VOTE_COST_AMT}" "${voter_name}"
    ;;
  query-params)
    shift; echo ">> Querying contract params..."

    query="${QUERY_PARAMS}"

    SelectLatestCodeInstance "${CONTRACT_OWNER_NAME}"
    QueryContractSmart "${query}"
    PrintQueryResults
    ;;
  query-voting)
    shift; echo ">> Querying voting info..."
    if [ $# != 1 ]; then
      echo "Usage: {votingID}"
      exit 1
    fi
    voting_id="$1"; shift

    query="${QUERY_VOTING//%id%/$voting_id}"

    SelectLatestCodeInstance "${CONTRACT_OWNER_NAME}"
    echo $query
    QueryContractSmart "${query}"
    PrintQueryResults
    ;;
  query-tally)
    shift; echo ">> Querying voting tally (vote progress)..."
    if [ $# != 1 ]; then
      echo "Usage: {votingID}"
      exit 1
    fi
    voting_id="$1"; shift

    query=${QUERY_TALLY//%id%/$voting_id}

    SelectLatestCodeInstance "${CONTRACT_OWNER_NAME}"
    QueryContractSmart "${query}"
    PrintQueryResults
    ;;
  query-open)
    shift; echo ">> Querying active votings..."

    query=${QUERY_OPEN}

    SelectLatestCodeInstance "${CONTRACT_OWNER_NAME}"
    QueryContractSmart "${query}"
    PrintQueryResults
    ;;
  query-release-stats)
    shift; echo ">> Querying release statistics..."

    query=${QUERY_RELEASE_STATS}

    SelectLatestCodeInstance "${CONTRACT_OWNER_NAME}"
    QueryContractSmart "${query}"
    PrintQueryResults
    ;;
  sudo-newvoting-cost)
    shift; echo ">> Changing the NewVotingCost..."

    msg=${SUDO_CHANGE_NEWVOTING_COST//%denom%/$STAKE_DENOM}
    msg=${msg//%amount%/$NEWVOTING_COST_SUDO_AMT}

    SelectLatestCodeInstance "${CONTRACT_OWNER_NAME}"
    SubmitSudoProposal "${msg}" "NewVoting cost change" "Lower the cost just because"
    ;;
  sudo-vote-cost)
    shift; echo ">> Changing the VoteCost..."

    msg=${SUDO_CHANGE_VOTE_COST//%denom%/$STAKE_DENOM}
    msg=${msg//%amount%/$VOTE_COST_SUDO_AMT}

    SelectLatestCodeInstance "${CONTRACT_OWNER_NAME}"
    SubmitSudoProposal "${msg}" "Vote cost change" "Lower the cost just because"
    ;;
  tracking-history)
    shift

    PrintGasRewardsTrackingHistory
    ;;
  *)
    echo "Unsupported cmd"
    echo
    echo "Usage: $0 {cmd}"
    echo "Default chain config: ${DEF_CHAIN_CONFIG}"
    echo "-c | --config - use alternative chain config"
    echo
    echo "Message: release, new-voting, vote, vote-ibc"
    echo "Query: query-params, query-voting, query-tally, query-open, query-release-stats, query-custom"
    echo "Sudo: sudo-newvoting-cost, sudo-vote-cost"
    echo "Other: init, info, balance-contract, balance-owner, tracking-history"
    exit 1
    ;;
  esac
done
