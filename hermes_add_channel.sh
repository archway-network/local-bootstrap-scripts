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
existing_connection_id=$(${HERMESD} --config "${HERMES_CONFIG_PATH}" --json query connections --chain "${CHAIN1_ID}" | jq -r '.result[0]')
echo "-> Creating channel for existing connection ${existing_connection_id}: ${CHAIN1_ID}.${CHAIN1_IBC_PORT} -> ${CHAIN2_ID}.${CHAIN2_IBC_PORT}, ${ibc_order}, ${ibc_version}"
  # >>
  ${HERMESD} --config "${HERMES_CONFIG_PATH}" create channel \
    --a-chain "${CHAIN1_ID}" \
    --a-connection "${existing_connection_id}" \
    --a-port "${CHAIN1_IBC_PORT}" \
    --b-port "${CHAIN2_IBC_PORT}" \
    --order "${ibc_order}" \
    --channel-version "${ibc_version}" \
    --yes
echo
