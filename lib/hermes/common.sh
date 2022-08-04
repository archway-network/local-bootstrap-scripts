# Chain IDs from configs.
CHAIN1_ID=$(sed -n 's/^CHAIN_ID="\(.*\)"/\1/p' "${CHAIN1_CONFIG}")
CHAIN2_ID=$(sed -n 's/^CHAIN_ID="\(.*\)"/\1/p' "${CHAIN2_CONFIG}")

# Hermes relayer home directory path and config path.
HERMES_DIR="${HERMES_DIR}/hermes_${CHAIN1_ID}_${CHAIN2_ID}"
HERMES_CONFIG_PATH="${HERMES_DIR}/config.toml"
