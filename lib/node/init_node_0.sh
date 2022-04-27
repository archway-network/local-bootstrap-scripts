#!/bin/bash

set -e

IFS=',' read -r -a SKIP_GENACC_NAMES <<< "${SKIP_GENACC_NAMES}"

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source "$(dirname ${DIR})/common.sh"

# Define node params
NODE_ID=0
NODE_DIR="${NODE_DIR_PREFIX}${NODE_ID}"
NODE_MONIKER="${NODE_MONIKER_PREFIX}${NODE_ID}"
CLI_COMMON_FLAGS="--home ${NODE_DIR}"

##
echo "Preparing directories"
  rm -rf "${COMMON_DIR}"
  rm -rf "${NODE_DIR}"

  mkdir -p "${KEYRING_DIR}"
  mkdir -p "${COMMON_DIR}/gentx"
  mkdir -p "${NODE_DIR}"
echo

##
echo "Init node: 0"
  cli_init_flags="${CLI_COMMON_FLAGS} --chain-id ${CHAIN_ID}"

  # >>
  ${COSMOSD} init ${NODE_MONIKER} ${cli_init_flags} &> "${COMMON_DIR}/${NODE_MONIKER}_info.json"

  AppConfig_setPorts ${NODE_ID}

  echo "  PEX:                  on"
  echo "  Seed mode:            on"
  echo "  AddrBook strict mode: on"
  sed -i.bak -e 's;seed_mode = false;seed_mode = true;' "${NODE_DIR}/config/config.toml"
  sed -i.bak -e 's;addr_book_strict = true;addr_book_strict = false;' "${NODE_DIR}/config/config.toml"

  if [ ! -z "${EXPORTED_GENESIS}" ]; then
    echo "  Replace default genesis with an exported one"
    cp "${EXPORTED_GENESIS}" "${NODE_DIR}/config/genesis.json"
  fi
echo

##
echo "Fix for single node setup"
  NODES_CNT_FIX=$NODES_CNT
  if [ "${NODES_CNT}" -eq "1" ]; then
    NODES_CNT_FIX=3
    echo "  Hard fix for 3 nodes"
  fi
echo

##
echo "Build account names list (keys add, add-genesis-account)"
  accnames_unfiltered=("${ACCNAME_BANK}")
  for i in $(seq 1 $NODES_CNT_FIX); do
    accnames_unfiltered+=("${ACCPREFIX_VALIDATOR}${i}")
  done

  ACCNAMES=()
  for accname_raw in "${accnames_unfiltered[@]}"; do
    skip=false

    for accname_filtered in "${SKIP_GENACC_NAMES[@]}"; do
      if [ "${accname_raw}" == "${accname_filtered}" ]; then
        skip=true
        echo "  ${accname_raw}: skipped"
        break
      fi
    done

    if ! $skip; then
      ACCNAMES+=(${accname_raw})
    fi
  done

  echo "  Active account names: ${ACCNAMES[@]}"
echo

##
echo "Add keys"
  for accname in "${ACCNAMES[@]}"; do
    Keys_createSafe ${accname}
    echo "  ${accname}: key created (or skipped if already exists)"
  done
echo

##
echo "Add genesis accounts"
  if ! $SKIP_GENESIS_OPS; then
    cli_genacc_flags="${CLI_COMMON_FLAGS} --keyring-backend ${KEYRING_BACKEND} --output json"

    for accname in "${ACCNAMES[@]}"; do
      # >>
      ${COSMOSD} add-genesis-account $(Keys_getAddr ${accname}) ${GENACC_COINS} ${cli_genacc_flags}

      echo "  ${accname}: genesis account added"
    done
  else
    echo "  Operation skipped"
  fi
echo

##
echo "Change other genesis settings"
  if ! $SKIP_GENESIS_OPS; then
    printf "$(jq '.app_state.gov.voting_params.voting_period = "300s"' ${NODE_DIR}/config/genesis.json)" > ${NODE_DIR}/config/genesis.json
  else
    echo "  Operation skipped"
  fi
echo

##
echo "Validate genesis"
  # >>
  ${COSMOSD} validate-genesis "${NODE_DIR}/config/genesis.json" ${CLI_COMMON_FLAGS}

  cp "${NODE_DIR}/config/genesis.json" "${COMMON_DIR}/genesis.json"
echo

##
echo "Collect peers data"
  cli_tm_flags="${CLI_COMMON_FLAGS}"

  # >>
  ${COSMOSD} tendermint show-node-id ${cli_tm_flags} > "${COMMON_DIR}/${NODE_MONIKER}_nodeID"
echo
