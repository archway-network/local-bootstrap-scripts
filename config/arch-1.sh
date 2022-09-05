# ---------- Base ------------------------------------------------------------------------------------------------------

## Chain ID.
### That ID is also used as an account name prefix for default accounts:
###   - {CHAIN_ID}_local-bank;
###   - {CHAIN_ID}_local-validator-1, ...;
CHAIN_ID="arch-1"

## Local cluster file path base.
### Account secrets, nodes data, configs, genesis, genTxs are stored here.
CLUSTER_DIR="${HOME}/archway/local/arch-1"

## Cluster size (must be GTE 1)
### Value also defines the number of validator accounts generated.
### Nodes can be added later using the "node_add_to_cluster.sh" script.
NODES_CNT=3

## Account Bech32 address prefix.
BECH32_PREFIX="archway"

## Main coin denom for staking and fees.
STAKE_DENOM="uarch" # micro-arch (10^6)

## Cosmos-based chain binary path.
COSMOSD="archwayd"

## Keyring storage.
### "os" / "file".
KEYRING_BACKEND="os"

## Node logging level.
NODE_LOGLEVEL="info"

## Default transaction fee.
### Used by various cluster post-start scripts (like "node_add_to_cluster.sh").
DEF_TX_FEES="1000000${STAKE_DENOM}" # 1.0 arch (more than enough for a single tx)

# ---------- Network ---------------------------------------------------------------------------------------------------

## Node urls.
### This is only used by contract /scripts.
NODE_RPC_URL="tcp://localhost"

## Node ports.
### Concrete ports. If defined, they are used as is instead of using prefixes.
### This is only used by contract /scripts.
NODE_RPC_PORT=""

## Node port prefixes.
### Actual port number is a combination of a prefix and a node index ({NODE_P2P_PORT_PREFIX}0, ...).
NODE_P2P_PORT_PREFIX="2666"
NODE_RPC_PORT_PREFIX="2667"
NODE_PROXY_PORT_PREFIX="2665"
NODE_GRPC_PORT_PREFIX="919"
NODE_GRPC_WEB_PORT_PREFIX="929"

# ---------- Genesis ---------------------------------------------------------------------------------------------------

## Exported genesis path.
### If not empty, the default generated genesis file is replaced with that one.
EXPORTED_GENESIS=""

## Skip genesis generation operations.
### Genesis defaults replacement, "add-genesis-account" operations are skipped.
SKIP_GENESIS_OPS=false

## List of account names that should not be generated.
### Those accounts should be imported to the local keyring using the "import_genesis_acc.sh" script before cluster init.
SKIP_GENACC_NAMES=""

# ----------- Genesis defaults -----------------------------------------------------------------------------------------

## Consensus params: block gas limit.
GEN_CONSENSUS_BLOCK_GAS_LIMIT="100000000" # 100_000_000

## x/mint module: min inflation rate.
GEN_MINT_MIN_INFLATION="0.10" # 10%

## x/mint module: max inflation rate.
GEN_MINT_MAX_INFLATION="0.10" # 10%

## x/mint module: max inflation rate.
GEN_MINT_BLOCKS_PER_YEAR="31557600" # 1 seconds block time

## x/gov module: voting duration.
GEN_GOV_VOTING_PERIOD="30s"

# ---------- Total supply ----------------------------------------------------------------------------------------------

## Bank balance (comma-separated list).
### Initial balance of the "local-bank" account.
BANK_COINS="540000000000000${STAKE_DENOM}" # 540_000_000.0 arch (1B - 3 validators - 1 relayer)

## Relayer balance (comma-separated list).
### Initial balance of the "local-relayer" account.
RELAYER_COINS="10000000000000${STAKE_DENOM}" # 10_000_000 arch

## Validator balance (comma-separated list).
### Initial balance of the "local-validator" accounts (number of accounts depends on the {NODES_CNT}).
### Value is also used by the "node_add_to_cluster.sh" script to transfer some tokens from the bank account
### for a new validator to start.
VALIDATOR_COINS="150000000000000${STAKE_DENOM}" # 150_000_000.0 arch

## Extra accounts balance (comma-separated list).
### Initial balance of {EXTRA_ACCOUNTS} accounts.
EXTRA_COINS=""

## Additional accounts to be generated [BASH array].
### Example: EXTRA_ACCOUNTS=("${CHAIN_ID}_faucet")
EXTRA_ACCOUNTS=()

# ---------- Validation ------------------------------------------------------------------------------------------------

## Min self delegation amount for all validators (base and new).
### Value is also used by the "node_add_to_cluster.sh" as an amount of tokens to be staked for a new node.
MIN_SELF_DELEGATION_AMT="1000000000" # 1_000.0 arch

## Self-delegation value for base validators.
BASENODE_STAKE="100000000000000${STAKE_DENOM}" # 100_000_000.0 arch
