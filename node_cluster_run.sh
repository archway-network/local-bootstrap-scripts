#!/bin/bash

set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source "${DIR}/config.sh"

for i in $(seq 0 $NODES_CNT); do
  echo "-> Starting node: tmux session: node_${i}"
  session_id="node_${i}"
  runner="${DIR}/node_run.sh ${i}"
  tmux new -d -s ${session_id} ${runner}
done
