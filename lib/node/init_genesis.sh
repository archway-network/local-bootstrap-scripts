#!/bin/bash

set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source "$(dirname ${DIR})/common.sh"

NODE_ID=0
NODE_DIR="${NODE_DIR_PREFIX}${NODE_ID}"
CLI_COMMON_FLAGS="--home ${NODE_DIR}"

echo "Collect genesis TXs and validate"
  cp "${NODE_DIR}/config/genesis.json" "${COMMON_DIR}/genesis.json.orig"

  # >>
  ${COSMOSD} collect-gentxs --gentx-dir "${COMMON_DIR}/gentx" ${CLI_COMMON_FLAGS} &> /dev/null
  ${COSMOSD} validate-genesis ${CLI_COMMON_FLAGS}
  
  cp "${NODE_DIR}/config/genesis.json" "${COMMON_DIR}/genesis.json"
echo

echo "Distribute genesis.json to nodes"
  for i in $(seq 1 $NODES_CNT); do
    cp "${COMMON_DIR}/genesis.json" "${NODE_DIR_PREFIX}${i}/config/genesis.json"
    echo "  copied to node ${i}"
  done
echo
