#!/bin/bash

set -e

# Imports
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source "${DIR}/lib/read_flags.sh"
source "${DIR}/lib/hermes/common.sh"

#
echo "-> Preparing directories"
  rm -rf "${HERMES_DIR}"

  mkdir -p "${HERMES_DIR}"
echo "-> Done"
echo

#
echo "-> Create config"
  cp "${DIR}/lib/hermes/config_base.template" "${HERMES_CONFIG_PATH}"

  sed -i.bak -e 's;{restPort};'"${HERMES_REST_PORT}"';' "${HERMES_CONFIG_PATH}"
  sed -i.bak -e 's;{telemetryPort};'"${HERMES_TELEMETRY_PORT}"';' "${HERMES_CONFIG_PATH}"
echo "-> Done"
echo

#
echo "-> Append chain configurations"
  ${DIR}/lib/hermes/init_chain.sh "${CONFIG_PATH}" "${CHAIN1_CONFIG}"
  ${DIR}/lib/hermes/init_chain.sh "${CONFIG_PATH}" "${CHAIN2_CONFIG}"
echo "-> Done"
echo

#
echo "-> Validate config"
  ${HERMESD} --config "${HERMES_CONFIG_PATH}" config validate
  rm "${HERMES_CONFIG_PATH}.bak"
echo "-> Done"
echo

#
echo "Paths configuration"
  for path_name in "${PATHS[@]}"; do
    path_data="$path_name[@]"

    path_opts=()
    for v in "${!path_data}"; do
      case $v in
        "1->2")
          path_opts+=("${CHAIN1_ID}")
          path_opts+=("${CHAIN2_ID}")
          ;;
        "2->1")
          path_opts+=("${CHAIN2_ID}")
          path_opts+=("${CHAIN1_ID}")
          ;;
       *)
         path_opts+=("$v")
         ;;
      esac
    done

    src_chain_id="${path_opts[0]}"
    dst_chain_id="${path_opts[1]}"
    src_port="${path_opts[2]}"
    dst_port="${path_opts[3]}"
    ibc_order="${path_opts[4]}"
    ibc_version="${path_opts[5]}"
    echo "  Creating channel (${path_name}): ${src_chain_id}.${src_port} -> ${dst_chain_id}.${dst_port}, ${ibc_order}, ${ibc_version}"

    # >>
    ${HERMESD} --config "${HERMES_CONFIG_PATH}" create channel --a-chain "${src_chain_id}" --b-chain "${dst_chain_id}" --a-port "${src_port}" --b-port "${dst_port}" --order "${ibc_order}" --channel-version "${ibc_version}" --new-client-connection --yes
  done
echo "-> Done"
echo

#
echo "-> Health check"
  # >>
  ${HERMESD} --config "${HERMES_CONFIG_PATH}" health-check
echo "-> Done"
echo

echo "Start manually with: ${HERMESD} --config ${HERMES_CONFIG_PATH} start"
