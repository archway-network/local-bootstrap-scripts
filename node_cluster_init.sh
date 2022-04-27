#!/bin/bash

set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source "${DIR}/config.sh"

echo "-> Configuring node 0 (seed)"
  "${DIR}/lib/node/init_node_0.sh"
echo "-> Done"
echo

for i in $(seq 1 $NODES_CNT); do
  echo "-> Configuring node ${i}"
  "${DIR}/lib/node/init_node_n.sh" ${i}
  echo "-> Done"
  echo
done

echo "-> Configuring genesis"
  "${DIR}/lib/node/init_genesis.sh"
echo "-> Done"

echo "-> Configuring p2p network"
  "${DIR}/lib/node/init_peers.sh"
echo "-> Done"
echo
