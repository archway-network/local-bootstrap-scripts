#!/bin/bash

set -e

# Imports
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source "${DIR}/lib/read_flags.sh"
source "${DIR}/lib/hermes/common.sh"

#
session_id="${CHAIN1_ID}_${CHAIN2_ID}_hermes"
echo "-> Starting hermes: tmux session: ${session_id}"
  runner="${HERMESD} --config ${HERMES_CONFIG_PATH} start"
  tmux new -d -s ${session_id} ${runner}
