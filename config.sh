# Binaries
## Cosmos-based chain binary path
COSMOSD="archwayd"

# Local cluster file path base
## Account secrets, nodes data and configs, genesis, genTxs, etc.
CLUSTER_DIR="${HOME}/archway/local"

# Chain ID
CHAIN_ID="arch-local"

# Cluster size (must be GTE 1)
## Nodes can be added later using node_add_to_cluster.sh script
NODES_CNT=3

# Exported genesis path
## If not empty, the default generated genesis file is replaced with that one
EXPORTED_GENESIS=""

# Skip genesis generation operations
## Oracle and assets creation, genTxs, etc.
SKIP_GENESIS_OPS=false

# List of account names that should not be generates ("local-validator-1,local-validator-2,local-validator-3,local-oracle1")
## Those accounts should be imported to the local keyring using import_genesis_acc.sh script before cluster init
SKIP_GENACC_NAMES=""

# Generated accounts balance
GENACC_COINS="1000000000ARCH,1000000000stake"

# Min self delegation amount for all validators (base and new)
MIN_SELF_DELEGATION_AMT="1000000000"

# Self-delegation value for base validators
BASENODE_STAKE="${MIN_SELF_DELEGATION_AMT}stake"

# New validator balance that is transferred from local-bank
## Value is used by the node_add_to_cluster.sh script to transfer some tokens for a new validator to start
NEWNODE_ACC_COINS="1000ARCH"

# Self-delegation value for new validators
NEWNODE_STAKE="${MIN_SELF_DELEGATION_AMT}stake"

# Node logging level
NODE_LOGLEVEL="info"

# Kering storage
## "os" / "file"
KEYRING_BACKEND="os"
