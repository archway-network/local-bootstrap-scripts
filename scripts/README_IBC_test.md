# Local IBC text messages chat test

Article describes how to run two Cosmos chains (Archway and custom Gaia) on a local machine, instantiate the Chat CosmWasm contract using helper scripts.

## Preparation

### 1. Build CowmWasm contract

```bash
# Goto Rust project directory
mkdir -p $HOME/Rust_Projects && cd "$_"

# Clone the contract repo
git clone git@github.com:archway-network/chat-contract.git archway/chat-contract

# Clone the CosmWasm Storage+ dependency repo
git clone git@github.com:CosmWasm/cw-plus.git CosmWasm/cw-plus

# Build
cd Archway/chat-contract
RUSTFLAGS='-C link-arg=-s' cargo wasm
```

Refer to [contract readme](https://github.com/archway-network/chat-contract/blob/master/README.md) for more details about the dependency above.

### 2. Build Gaia binary

```bash
# Goto Go Archway projects directory
mkdir -p $HOME/Go_Projects/src/github.com/archway-network && cd "$_"

# Clone the repo
git clone git@github.com:archway-network/gaia.git && cd gaia

# Switch to x/chat branch
git checkout archway_chat_module

# Build (binary should appear at $GOPATH/bin/gaiad)
make install
```

### 3. Build Archway binary

```bash
# Goto Go Archway projects directory
mkdir -p $HOME/Go_Projects/src/github.com/archway-network && cd "$_"

# Clone the repo
git clone git@github.com:archway-network/archway.git && cd archway

# Build (binary should appear at $GOPATH/bin/archwayd)
make install
```

### 4. Build Cosmos Relayer binary

```bash
# Goto Go Archway projects directory
mkdir -p $HOME/Go_Projects/src/github.com/cosmos && cd "$_"

# Clone the repo
git clone git@github.com:cosmos/relayer.git && cd relayer

# Build (binary should appear at $GOPATH/bin/rly)
make install
```

### 5. Init and run local clusters

Make sure `archwayd`, `gaiad` and `rly` binaries are "visible" through `$PATH` and `tmux` is installed (`brew install tmux`).

For more details on how that works refer to [README.md](../README.md) for this repo.

```bash
# Goto this repo
cd $HOME/Archway/local-bootstrap-scripts

# Init (arch-1, gaiaB-1) and run chains
./node_cluster_init.sh -c config/arch-1.sh; ./node_cluster_init.sh -c config/gaiaB.sh; ./node_cluster_run.sh -c config/arch-1.sh; ./node_cluster_run.sh -c config/gaiaB.sh; ./wait_for_block.sh -c config/arch-1.sh 2
```

We're using [arch-1](../config/arch-1.sh) and [gaiaB-1](../config/gaiaB.sh) configs to start two clusters (8 nodes in total) and we wait for 2 block (to ensure chains are ready to receive TXs).

To check that everything is up and running:

```bash
# List tmux sessions (there should be 8 of them)
tmux ls

# To view a session logs
tmux a -t gaiaB-1_node_1
# To exit: Ctrl+b, d
```

To stop two clusters and the relayer:

```bash
./stop_cluster.sh -c config/arch-1.sh; ./stop_cluster.sh -c config/gaiaB.sh; ./stop_relayer.sh -c config/relayer_archGaiaB.sh
```

### 6. Deploy the contract

Ensure `CONTRACT_BYTECODE_PATH` and `RELAYER_CONFIG` variables are correct for your machine within [scripts/cw_arch.sh](./scripts/cw_arch.sh) file. If all paths on previous steps were correct, those two are correct also.

```bash
# Assuming you're still in this repo directory
scripts/cw_arch.sh cw-init
```

That command would upload the contract, instantiate it and modify the [relayer_config](../config/relayer_archGaiaB.sh) `CONTRACT_PORT_ID` field.

### 7. Init and run Cosmos Relayer

```bash
./relayer_init.sh -c config/relayer_archGaiaB.sh; ./relayer_run.sh -c config/relayer_archGaiaB.sh
```

Step would init the Relayer, add chain / IBC path configs and start the relayer. That would take some time since it creates clients, channels and sets consensus states for IBC. If everything went well, I would a status of the IBC connection with ✔️s.

## Usage

### Sending a message

For IBC send the following accounts are used:

* `arch-1_local-bank` for Archway's `arch-1` network;
* `gaiaB-1_local-bank` - for Gaia's `gaiaB-1` network;

For local send:

* `arch-1_local-bank`;
* `arch-1_local-validator-1`;

```bash
# Archway's contract -> Gaia
scripts/cw_arch.sh cw-send-ibc "Hello from CowmWasm 1"

# Gaia -> Archway's contract
scripts/cw_arch.sh gaia-send-ibc "Hello from Gaia 1"

# Contract -> contract (local send)
scripts/cw_arch.sh cw-send-local "Hello from local 1"
```

### Chat history

```bash
# Archway's contract -> Gaia
scripts/cw_arch.sh cw-history-ibc

# Gaia -> Archway's contract
scripts/cw_arch.sh gaia-history-ibc

# Contract -> contract (local send)
scripts/cw_arch.sh cw-history-local
```

`is_delivered` field value (for CosmWasm contract) or ✅/❌ sign (for Gaia) indicates if a particular message was delivered (IBC acknowledged). Acknowledgement might take some time (2-3 blocks).

## Gaia to Gaia test

You can also run two Gaia networks (`gaiaA` and `gaiaB`) and check the IBC exchange between them.

For this you could use the [scripts/gaiaAB.sh](../scripts/gaiaAB.sh) script which is simmilar to the `cw_arch.sh` described above (scroll to the bottom of it for init, run and stop commands to use).