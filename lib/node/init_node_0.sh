IFS=',' read -r -a SKIP_GENACC_NAMES <<< "${SKIP_GENACC_NAMES}"

# Define node params
node_id=0
node_dir="${NODE_DIR_PREFIX}${node_id}"
node_moniker="${NODE_MONIKER_PREFIX}${node_id}"
cli_common_flags="--home ${node_dir}"

##
echo "Preparing directories"
  rm -rf "${COMMON_DIR}"
  rm -rf "${node_dir}"

  mkdir -p "${KEYRING_DIR}"
  mkdir -p "${COMMON_DIR}/gentx"
  mkdir -p "${node_dir}"
echo

##
echo "Init node: 0"
  cli_init_flags="${cli_common_flags} --chain-id ${CHAIN_ID}"

  # >>
  ${COSMOSD} init ${node_moniker} ${cli_init_flags} &> "${COMMON_DIR}/${node_moniker}_info.json"

  AppConfig_setPorts ${node_id}

  echo "  PEX:                  on"
  echo "  Seed mode:            on"
  echo "  AddrBook strict mode: on"
  sed -i.bak -e 's;seed_mode = false;seed_mode = true;' "${node_dir}/config/config.toml"
  sed -i.bak -e 's;addr_book_strict = true;addr_book_strict = false;' "${node_dir}/config/config.toml"

  if [ -n "${EXPORTED_GENESIS}" ]; then
    echo "  Replace default genesis with an exported one"
    cp "${EXPORTED_GENESIS}" "${node_dir}/config/genesis.json"
  fi
echo

##
echo "Fix for single node setup"
  NODES_CNT_FIX=$NODES_CNT
  if [ "${NODES_CNT}" -eq "1" ]; then
    NODES_CNT_FIX=3
    echo "  Hard fix for 3 nodes"
  fi
echo

##
echo "Build account names list (keys add, add-genesis-account)"
  accnames_unfiltered=("${ACCNAME_BANK}" "${ACCNAME_RELAYER}")
  accnames_unfiltered=("${accnames_unfiltered[@]}" "${EXTRA_ACCOUNTS[@]} ")
  for i in $(seq 1 $NODES_CNT_FIX); do
    accnames_unfiltered+=("${ACCPREFIX_VALIDATOR}${i}")
  done

  accnames=()
  for accname_raw in "${accnames_unfiltered[@]}"; do
    skip=false

    for accname_filtered in "${SKIP_GENACC_NAMES[@]}"; do
      if [ "${accname_raw}" == "${accname_filtered}" ]; then
        skip=true
        echo "  ${accname_raw}: skipped"
        break
      fi
    done

    if ! $skip; then
      accnames+=(${accname_raw})
    fi
  done

  echo "  Active account names: ${accnames[@]}"
echo

##
echo "Add keys"
  for accname in "${accnames[@]}"; do
    Keys_createSafe ${accname}
    # Keys_createWithOverride ${accname}
    echo "  ${accname}: key created (or skipped if already exists)"
  done
echo

##
echo "Add genesis accounts"
  if ! $SKIP_GENESIS_OPS; then
    cli_genacc_flags="${cli_common_flags} --keyring-backend ${KEYRING_BACKEND} --output json"

    for accname in "${accnames[@]}"; do
      accbalance=""
      if [[ $accname == ${ACCNAME_BANK}* ]]; then
        accbalance="${BANK_COINS}"
      fi
      if [[ $accname == ${ACCNAME_RELAYER}* ]]; then
              accbalance="${RELAYER_COINS}"
            fi
      if [[ $accname == ${ACCPREFIX_VALIDATOR}* ]]; then
        accbalance="${VALIDATOR_COINS}"
      fi
      for extraname in "${EXTRA_ACCOUNTS[@]}"; do
        if [[ $accname == ${extraname}* ]]; then
          accbalance="${EXTRA_COINS}"
        fi
      done

      # >>
      ${COSMOSD} add-genesis-account $(Keys_getAddr ${accname}) ${accbalance} ${cli_genacc_flags}

      echo "  ${accname}: genesis account added with ${accbalance} coins"
    done
  else
    echo "  Operation skipped"
  fi
echo

##
echo "Change other genesis settings"
  if ! $SKIP_GENESIS_OPS; then
    # Consensus
    printf "$(jq '.consensus_params.block.max_gas = "%s"' ${node_dir}/config/genesis.json)" "${GEN_CONSENSUS_BLOCK_GAS_LIMIT}" > ${node_dir}/config/genesis.json
    # x/staking
    printf "$(jq '.app_state.staking.params.bond_denom = "%s"' ${node_dir}/config/genesis.json)" "${STAKE_DENOM}" > ${node_dir}/config/genesis.json
    # x/mint
    printf "$(jq '.app_state.mint.params.mint_denom = "%s"' ${node_dir}/config/genesis.json)" "${STAKE_DENOM}" > ${node_dir}/config/genesis.json
    printf "$(jq '.app_state.mint.params.inflation_min = "%s"' ${node_dir}/config/genesis.json)" "${GEN_MINT_MIN_INFLATION}" > ${node_dir}/config/genesis.json
    printf "$(jq '.app_state.mint.params.inflation_max = "%s"' ${node_dir}/config/genesis.json)" "${GEN_MINT_MAX_INFLATION}" > ${node_dir}/config/genesis.json
    printf "$(jq '.app_state.mint.params.blocks_per_year = "%s"' ${node_dir}/config/genesis.json)" "${GEN_MINT_BLOCKS_PER_YEAR}" > ${node_dir}/config/genesis.json
    # x/gov
    printf "$(jq '.app_state.gov.voting_params.voting_period = "%s"' ${node_dir}/config/genesis.json)" "${GEN_GOV_VOTING_PERIOD}" > ${node_dir}/config/genesis.json
    printf "$(jq '.app_state.gov.deposit_params.min_deposit[0].denom = "%s"' ${node_dir}/config/genesis.json)" "${STAKE_DENOM}" > ${node_dir}/config/genesis.json
    # x/crisis
    printf "$(jq '.app_state.crisis.constant_fee.denom = "%s"' ${node_dir}/config/genesis.json)" "${STAKE_DENOM}" > ${node_dir}/config/genesis.json
  else
    echo "  Operation skipped"
  fi
echo

##
echo "Validate genesis"
  # >>
  ${COSMOSD} validate-genesis "${node_dir}/config/genesis.json" ${cli_common_flags}

  cp "${node_dir}/config/genesis.json" "${COMMON_DIR}/genesis.json"
echo

##
echo "Collect peers data"
  cli_tm_flags="${cli_common_flags}"

  # >>
  ${COSMOSD} tendermint show-node-id ${cli_tm_flags} > "${COMMON_DIR}/${node_moniker}_nodeID"
echo
