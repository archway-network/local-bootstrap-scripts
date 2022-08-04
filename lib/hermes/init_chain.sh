#!/bin/bash

set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# Inputs
HERMES_CONFIG="$1"
CHAIN_CONFIG="$2"

# Read relayer and chain configs
source "$(dirname ${DIR})/read_flags.sh" -c "${CHAIN_CONFIG}"
source "$(dirname ${DIR})/node/common.sh"

source "$(dirname ${DIR})/read_flags.sh" -c "${HERMES_CONFIG}"
source "${DIR}/common.sh"

#
echo "Append ${CHAIN_ID} chain configuration"
  tmp_file="${HERMES_DIR}/${CHAIN_ID}_config.toml"
  cp "${DIR}/config_chain.template" "${tmp_file}"

  sed -i.bak -e 's;{chainID};'"${CHAIN_ID}"';' "${tmp_file}"
  sed -i.bak -e 's;{rpcPortPrefix};'"${NODE_RPC_PORT_PREFIX}"';' "${tmp_file}"
  sed -i.bak -e 's;{grpcPortPrefix};'"${NODE_GRPC_PORT_PREFIX}"';' "${tmp_file}"
  sed -i.bak -e 's;{bech32Prefix};'"${BECH32_PREFIX}"';' "${tmp_file}"
  sed -i.bak -e 's;{relayerAccName};'"${ACCNAME_RELAYER}"';' "${tmp_file}"
  sed -i.bak -e 's;{baseDenom};'"${STAKE_DENOM}"';' "${tmp_file}"

  cat "${tmp_file}" >> "${HERMES_CONFIG_PATH}"
  rm "${tmp_file}"
  rm "${tmp_file}.bak"
echo

#
echo "Import ${RELAYER_ACC_NAME} account"
  tmp_file="${HERMES_DIR}/${ACCNAME_RELAYER}.mnemonic"
  echo "$(Keys_getMnemonic ${ACCNAME_RELAYER})" > "${tmp_file}"

  # >>
  ${HERMESD} --config "${HERMES_CONFIG_PATH}" keys delete --chain "${CHAIN_ID}" --all
  ${HERMESD} --config "${HERMES_CONFIG_PATH}" keys add --chain "${CHAIN_ID}" --mnemonic-file "${tmp_file}"

  rm "${tmp_file}"
echo
