#!/bin/bash

# Imports
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source "${DIR}/lib/read_flags.sh"

${COSMOSD} tx --chain-id ${CHAIN_ID} --node tcp://localhost:${NODE_RPC_PORT_PREFIX}1 --keyring-backend ${KEYRING_BACKEND} "$@"
