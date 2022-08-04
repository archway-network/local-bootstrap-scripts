# ---------- Base ------------------------------------------------------------------------------------------------------

## Hermes IBC relayer binary path.
HERMESD="hermes"

## Relayer file path base.
### Sub-directory with "hermes_{CHAIN1_ID}_{CHAIN2_ID}" name will be created.
HERMES_DIR="${HOME}/archway/local"

## Chain cluster configs.
CHAIN1_CONFIG="config/arch-1.sh"
CHAIN2_CONFIG="config/arch-2.sh"

# ---------- Network ---------------------------------------------------------------------------------------------------

## Hermes REST port.
HERMES_REST_PORT="3000"

## Hermes telemetry port.
HERMES_TELEMETRY_PORT="3001"

# ---------- Paths -----------------------------------------------------------------------------------------------------

## Paths (channels) configuration.
### This is a BASH array of arrays.
### Each array defines a single relayer path with the following values (by index):
###   0. "1->2" / "2->1". Defines a direction (chain 1 to chain 2 or vice versa);
###   1. Source port ID;
###   2. Destination port ID;
###   3. Order type ("ordered" / "unordered");
###   4. Version;
declare -a transfer_path=("1->2" "transfer" "transfer" "unordered" "ics20-1")
declare -a PATHS=("transfer_path")
