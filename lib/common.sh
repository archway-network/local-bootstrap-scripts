set -e
COMMON_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source "$(dirname ${COMMON_DIR})/config.sh"
set +e

# Folders
NODE_DIR_PREFIX="${CLUSTER_DIR}/anode_"
COMMON_DIR="${CLUSTER_DIR}/common"
KEYRING_DIR="${CLUSTER_DIR}/keyring"

# Local account names
ACCNAME_BANK="local-bank"
ACCPREFIX_VALIDATOR="local-validator-"

# Node ports
NODE_P2P_PORT_PREFIX="2666"
NODE_RPC_PORT_PREFIX="2667"
NODE_PROXY_PORT_PREFIX="2665"
NODE_GRPC_PORT_PREFIX="919"
NODE_GRPC_WEB_PORT_PREFIX="929"

# CLI flags
PASSPHRASE="passphrase"

# Other
NODE_MONIKER_PREFIX="node_"

# Join string array [$2...] with $1 IFS delimiter
function ArrayJoin {
  local IFS="$1"; shift; echo "$*";
}

# Set node ports for NODE_ID $1
function AppConfig_setPorts() {
  echo "Changing P2P / RPC ports"

  node_id=$1
  node_dir="${NODE_DIR_PREFIX}${node_id}"

  node_p2p_port="${NODE_P2P_PORT_PREFIX}${node_id}"
  node_rpc_port="${NODE_RPC_PORT_PREFIX}${node_id}"
  node_proxy_port="${NODE_PROXY_PORT_PREFIX}${node_id}"
  node_grpc_port="${NODE_GRPC_PORT_PREFIX}${node_id}"
  node_grpc_web_port="${NODE_GRPC_WEB_PORT_PREFIX}${node_id}"

  # config.toml
  sed -i.bak -e 's;laddr = \"tcp://0.0.0.0:26656\";laddr = \"tcp://0.0.0.0:'"${node_p2p_port}"'\";' "${node_dir}/config/config.toml"
  sed -i.bak -e 's;external_address = \"\";external_address = \"tcp://127.0.0.1:'"${node_p2p_port}"'\";' "${node_dir}/config/config.toml"
  sed -i.bak -e 's;laddr = \"tcp://127.0.0.1:26657\";laddr = \"tcp://127.0.0.1:'"${node_rpc_port}"'\";' "${node_dir}/config/config.toml"
  sed -i.bak -e 's;proxy_app = \"tcp://127.0.0.1:26658\";proxy_app = \"tcp://127.0.0.1:'"${node_proxy_port}"'\";' "${node_dir}/config/config.toml"
  sed -i.bak -e 's;allow_duplicate_ip = false;allow_duplicate_ip = true;' "${node_dir}/config/config.toml"

  # app.toml
  sed -i.bak -e 's;address = \"0.0.0.0:9090\";address = \"0.0.0.0:'"${node_grpc_port}"'\";' "${node_dir}/config/app.toml"
  sed -i.bak -e 's;address = \"0.0.0.0:9091\";address = \"0.0.0.0:'"${node_grpc_web_port}"'\";' "${node_dir}/config/app.toml"
}

# Print account $1 address
function Keys_getAddr {
  cli_keys_flags="--keyring-backend ${KEYRING_BACKEND} --keyring-dir ${KEYRING_DIR}"

  # >>
  addr=$(printf '%s\n' ${PASSPHRASE} | ${COSMOSD} keys show $1 -a ${cli_keys_flags})

  echo -n ${addr}
}

# Create account $1 key (if not exists) and save secret data to file
function Keys_createSafe {
  cli_keys_flags="--keyring-backend ${KEYRING_BACKEND} --keyring-dir ${KEYRING_DIR} --output json"

  set +e

  # >>
  acc_data=`printf '%s\n%s\n' ${PASSPHRASE} ${PASSPHRASE} | ${COSMOSD} keys add $1 ${cli_keys_flags} 2>&1`
  
  if [ $? -eq 0 ]; then
    echo $1
    echo ${acc_data} > "${KEYRING_DIR}/$1_key"
  fi

  set -e
}
