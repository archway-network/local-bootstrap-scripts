#!/bin/bash

set -e

NODE_ID=$1

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source "$(dirname ${DIR})/common.sh"

# Define node params
NODE_DIR="${NODE_DIR_PREFIX}${NODE_ID}"
NODE_MONIKER="${NODE_MONIKER_PREFIX}${NODE_ID}"
CLI_COMMON_FLAGS="--home ${NODE_DIR}"

##
echo "Preparing directories"
  rm -rf "${NODE_DIR}"

  mkdir -p "${NODE_DIR}"
echo

##
echo "Init node: ${NODE_ID}"
  cli_init_flags="${CLI_COMMON_FLAGS} --chain-id ${CHAIN_ID}"

  # >>
  ${COSMOSD} init ${NODE_MONIKER} ${cli_init_flags} &> "${COMMON_DIR}/${NODE_MONIKER}_info.json"

  AppConfig_setPorts ${NODE_ID}

  echo "  PEX:                  off"
  echo "  Seed mode:            off"
  echo "  AddrBook strict mode: off"
  sed -i.bak -e 's;pex = true;pex = false;' "${NODE_DIR}/config/config.toml"
  sed -i.bak -e 's;addr_book_strict = true;addr_book_strict = false;' "${NODE_DIR}/config/config.toml"
echo

##
echo "Genesis TX to create validator with default min self-delegation and min self-stake"
  if ! $SKIP_GENESIS_OPS; then
    cli_gentx_flags="${CLI_COMMON_FLAGS} --chain-id ${CHAIN_ID} --min-self-delegation ${MIN_SELF_DELEGATION_AMT} --keyring-backend ${KEYRING_BACKEND} --keyring-dir ${KEYRING_DIR} --output-document ${COMMON_DIR}/gentx/${NODE_ID}_gentx.json"

    cp "${COMMON_DIR}/genesis.json" "${NODE_DIR}/config/genesis.json"

    # >>
    printf '%s\n%s\n%s\n' ${PASSPHRASE} ${PASSPHRASE} ${PASSPHRASE} | ${COSMOSD} gentx ${ACCPREFIX_VALIDATOR}${NODE_ID} ${BASENODE_STAKE} ${cli_gentx_flags}
  else
    echo "  Operation skipped"
  fi
echo

##
echo "Collect peers data"
  cli_tm_flags="${CLI_COMMON_FLAGS}"

  # >>
  ${COSMOSD} tendermint show-node-id ${cli_tm_flags} > "${COMMON_DIR}/${NODE_MONIKER}_nodeID"
echo
