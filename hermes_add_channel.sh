#!/bin/bash

set -e

# Imports
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source "${DIR}/lib/read_flags.sh"
source "${DIR}/lib/hermes/common.sh"

# Input check: node ID
if [ $# -ne 4 ]; then
  echo "Usage: hermes_add_channel.sh [-c config_path] [chain1_ibc_port] [chain2_ibc_port] [ibc_order] [ibc_version]"
  exit
fi
CHAIN1_IBC_PORT="$1"
CHAIN2_IBC_PORT="$2"
ibc_order="$3"
ibc_version="$4"

#
echo "-> Creating channel: ${CHAIN1_ID}.${CHAIN1_IBC_PORT} -> ${CHAIN2_ID}.${CHAIN2_IBC_PORT}, ${ibc_order}, ${ibc_version}"
  # >>
  ${HERMESD} --config "${HERMES_CONFIG_PATH}" create channel --a-chain "${CHAIN1_ID}" --b-chain "${CHAIN2_ID}" --a-port "${CHAIN1_IBC_PORT}" --b-port "${CHAIN2_IBC_PORT}" --order "${ibc_order}" --channel-version "${ibc_version}" --new-client-connection --yes
echo
