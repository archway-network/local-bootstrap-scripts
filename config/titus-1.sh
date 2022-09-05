# This config is used by contracts' /scrips and it is a stripped down version of "arch-1.sh" (should not be used to run a local cluster).

# ---------- Base ------------------------------------------------------------------------------------------------------

## Chain ID.
CHAIN_ID="titus-1"

## Account Bech32 address prefix.
BECH32_PREFIX="archway"

## Main coin denom for staking and fees.
STAKE_DENOM="utitus" # micro-arch (10^6)

## Cosmos-based chain binary path.
COSMOSD="archwayd"

## Keyring storage.
### "os" / "file".
KEYRING_BACKEND="os"

# ---------- Network ---------------------------------------------------------------------------------------------------

## Node urls.
NODE_RPC_URL="https://rpc.titus-1.archway.tech"

## Node ports.
NODE_RPC_PORT="443"
