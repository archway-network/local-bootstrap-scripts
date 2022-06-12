#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source "${DIR}/lib/common.sh"

${COSMOSD} q --node tcp://localhost:${NODE_RPC_PORT_PREFIX}1 $@