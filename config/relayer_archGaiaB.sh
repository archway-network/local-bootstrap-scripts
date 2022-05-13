# Relayer home directory
RELAYER_DIR="${HOME}/archway/local/relayer_archGaiaB"

# Chain cluster configs
CHAIN1_CONFIG="config/arch-1.sh"
CHAIN2_CONFIG="config/gaiaB.sh"

# Relayer default IBC timeout
TIMEOUT="20s"

# Paths (channels)
## This is a BASH array of arrays.
## Each array defines a single relayer path with the following values (by index):
##   0. "1->2" / "2->1". Defines a direction (chain 1 to chain 2 or vice versa);
##   1. Source port ID;
##   2. Destination port ID;
##   3. Order type ("ordered" / "unordered");
##   4. Version;
CONTRACT_PORT_ID="wasm.archway14hj2tavq8fpesdwxxcu44rty3hh90vhujrvcmstl4zr3txmfvw9sy85n2u"
declare -a chat_path=("1->2" "${CONTRACT_PORT_ID}" "chat" "unordered" "chat-1")
# declare -a chat_pathBA=("2->1" "chat" "chat" "unordered" "chat-1")
# declare -a PATHS=("chat_pathAB" "chat_pathBA")
declare -a PATHS=("chat_path")
