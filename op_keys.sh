#!/bin/bash

# Imports
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source "${DIR}/lib/read_flags.sh"

${COSMOSD} keys --keyring-backend ${KEYRING_BACKEND} $@
