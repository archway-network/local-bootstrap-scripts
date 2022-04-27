#!/bin/bash

set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source "${DIR}/lib/common.sh"

# Input check: nodeID
if [ $# -eq 0 ]; then
  echo "Usage: node_run.sh node_id"
  exit
fi

NODE_ID=$1
if [ "${NODE_ID}" -lt 0 ]; then
  echo "node_id: must be GTE 0"
  exit
fi
NODE_DIR="${NODE_DIR_PREFIX}${NODE_ID}"

echo "-> Starting node ${NODE_ID}"
  echo "  Node dir: ${NODE_DIR}"

  # >>
  ${COSMOSD} start --home="${NODE_DIR}" --inv-check-period=5 --log_level=${NODE_LOGLEVEL}
echo "-> Node stopped"
