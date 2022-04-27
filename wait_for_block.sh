#!/bin/bash

set -e

blockGetter='archwayd q --node tcp://localhost:26671 block | jq -r ".block.header.height"'
blockLimit=500

echo "-> Cluster start"
./node_cluster_run.sh 3

while : ; do
  block=$(eval ${blockGetter})
  echo "-> Block: ${block} / ${blockLimit}"
  if [ "${block}" -ge "${blockLimit}" ]; then
    break
  fi
  sleep 5
done

echo "-> Cluster stop"
./stop_all.sh
