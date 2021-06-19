#!/bin/bash

export ACTION=${1}
export COIN=${2}
export COMMAND=${3}
#echo "https://lethean.sh/${1}/${2}/${3}"
export WALLET_PASSWORD="test"
export WALLET_RPC_PASSWORD="test"

export BASE_DIR="$(pwd)"

if [ -f "$BASE_DIR/settings/${COIN}.env" ]; then
  # shellcheck disable=SC1090
  . "${BASE_DIR}/settings/${COIN}".env
fi

export WALLET_DATA="${BASE_DIR}/wallets/${COIN}"
export WALLET_FILE="${WALLET_DATA}/wallet"
export CONFIG_PATH="${BASE_DIR}/config/wallets"
export CONFIG_FILE="${BASE_DIR}/config/wallets/${COIN}.env"
export SETTINGS_FILE="${BASE_DIR}/settings/${COIN}.env"
export LOGS_DATA="${BASE_DIR}/logs/${COIN}"
export WALLET_RPC="${BASE_DIR}/cli/${COIN}/lethean-wallet-rpc"
export WALLET_CLI="${BASE_DIR}/cli/${COIN}/${WALLET_CLI_BIN}"
export WALLET_VPN_RPC="${BASE_DIR}/cli/${COIN}/lethean-wallet-vpn-rpc"
export CHAIN_IMPORT="${BASE_DIR}/cli/${COIN}/lethean-blockchain-import"
export CHAIN_EXPORT="${BASE_DIR}/cli/${COIN}/lethean-blockchain-export"
export CHAIN_DAEMON="${BASE_DIR}/cli/${COIN}/letheand"
export CHAIN_DATA="${BASE_DIR}/data/${COIN}"
export BC_DATA="${BASE_DIR}/bc/${COIN}"
export BC_MODE="livenet"

export PORT_P2P="48772"
export PORT_RPC="48782"

runLiveNetDaemon() {
  echo "Livenet Blockchain"
  $CHAIN_DAEMON --non-interactive --config-file "${CONFIG_PATH}"/livenet.conf "$@"
}

runTestNetDaemon() {
  echo "Testnet Blockchain"
  $CHAIN_DAEMON --non-interactive --testnet --config-file "${CONFIG_PATH}"/testnet.conf "$@"
}

exportChain() {
  echo "Exporting Blockchain"
  $CHAIN_EXPORT --data-dir="$CHAIN_DATA/$BC_MODE" --output-file "$BC_DATA/$BC_MODE"/data.lmdb
}

importChain() {
  echo "Blockchain Importing"
  $CHAIN_IMPORT --data-dir="$CHAIN_DATA/$BC_MODE" --input-file "$BC_DATA/$BC_MODE"/data.lmdb
}

runWalletRPC() {

  if [ -z "$WALLET_RPC_URI" ]; then
    echo "Starting Wallet cli with $WALLET_FILE." >&2
    $WALLET_RPC --wallet-file "$WALLET_FILE" --daemon-host "localhost" --password "$WALLET_PASSWORD" --rpc-bind-port "$PORT_RPC" --confirm-external-bind --disable-rpc-login --trusted-daemon &
    sleep 4
    WALLET_RPC_URI="http://localhost:$PORT_RPC"
  else
    echo "Wallet is outside of container ($WALLET_RPC_URI)." >&2
  fi
}

makeWallet() {
  mkdir -p "${WALLET_DATA}"
  echo "Generating wallet $WALLET_FILE" >&2
  $WALLET_CLI --log-file "${LOGS_DATA}/wallet.log" --mnemonic-language English --generate-new-wallet "$WALLET_FILE" --command exit
  WALLET_ADDRESS=$(cat "${WALLET_FILE}.address.txt")
  echo "Created new wallet: ${WALLET_ADDRESS}"
  echo "Saved: $WALLET_FILE"
}

restoreWallet() {
  mkdir -p "${WALLET_DATA}"
  $WALLET_CLI --log-file "${LOGS_DATA}/wallet.log" --daemon-host "${DAEMON_HOST}" --restore-deterministic-wallet --generate-new-wallet "$WALLET_FILE"
  WALLET_ADDRESS=$(cat "${WALLET_FILE}.address.txt")
  echo "Created new wallet: ${WALLET_ADDRESS}"
  echo "Saved: $WALLET_FILE"
}

runWalletCmd() {
  cd "$WALLET_DATA" || initCoin "$@" || (echo "Cant CD into ${WALLET_DATA}" && exit 2)

  if ! [ -t 0 ]; then
    echo "You must allocate TTY to run letheand! Use -t option" && exit 3
  fi

  $WALLET_CLI --log-file "${LOGS_DATA}/wallet.log"  --daemon-host "$DAEMON_HOST" --wallet-file "${WALLET_FILE}"  --command "${*}"

}

initCoin() {

  # Create cli directory
  if [ ! -d "$CLI_DATA"/"${COIN}" ]; then
    echo "Creating $BASE_DIR/cli/${COIN}"
    mkdir -p "$BASE_DIR"/cli/"${COIN}" || errorExit 2 "Cant make: $BASE_DIR/cli/${1}"
    export CLI_DATA="$BASE_DIR/cli/${COIN}"
  fi

  # Create data directory
  if [ ! -d "$BASE_DIR"/data/"${COIN}" ]; then
    echo "Creating $BASE_DIR/data/${COIN}"
    mkdir -p "$BASE_DIR/data/${COIN}"
    export WALLET_DATA="$BASE_DIR/data/${COIN}"
  fi
  # Create wallet directory
  if [ ! -d "$BASE_DIR"/wallets/"${COIN}" ]; then
    echo "Creating $BASE_DIR/wallets/${COIN}"
    mkdir -p "$BASE_DIR/wallets/${COIN}"
    export WALLET_DATA="$BASE_DIR/wallets/${COIN}"
  fi

  # Create log directory
  if [ ! -d "$BASE_DIR"/logs/"${COIN}" ]; then
    echo "Creating $BASE_DIR/logs/${COIN}"
    mkdir -p "$BASE_DIR"/logs/"${COIN}"
    export LOGS_DATA="$BASE_DIR/logs/${COIN}"
  fi

  # Create config dir
  if [ ! -f "$SETTINGS_FILE" ]; then
    echo "Creating Base settings"
    mkdir -p "${SETTINGS_PATH}"
    cp "${CONFIG_FILE}" "${SETTINGS_FILE}"
  fi

}

case $ACTION in
wallet)
  shift
  case $COMMAND in
  restore)
    shift
    restoreWallet "$@"
    ;;
  new)
    shift
    makeWallet
  ;;
  open)
    shift
    echo  ${DAEMON_HOST}
    $WALLET_CLI --log-file "${LOGS_DATA}/wallet.log"  --daemon-host="${DAEMON_HOST}" --wallet-file "${WALLET_FILE}"
  ;;
  *)
    shift
    runWalletCmd balance
    ;;
  esac

  ;;

sync | letheand)
  shift
  runLiveNetDaemon "$@"
  ;;

daemon)
  shift
  runLiveNetDaemon --detach
  ;;

testnet)
  shift
  runTestNetDaemon "$@"
  ;;

export)
  shift
  exportChain "$@"
  ;;

import)
  shift
  importChain "$@"
  ;;

wallet-rpc)
  shift
  runWalletRPC "$@"
  unset HTTP_PROXY
  unset http_proxy
  shift
  while ! curl "$WALLET_RPC_URI" >/dev/null 2>/dev/null; do
    echo "Waiting for wallet rpc server."
    sleep 5
  done
  ;;

vpn-rpc)
  shift
  runWalletVPNRpc "$@"
  unset HTTP_PROXY
  unset http_proxy
  shift
  while ! curl "$WALLET_VPN_RPC_URI" >/dev/null 2>/dev/null; do
    echo "Waiting for vpn rpc server."
    sleep 5
  done
  ;;

test-seed-node)
  shift
  if [ -z "${*}" ]; then
    NODE_IP="35.217.36.217:48772"
  else
    NODE_IP="$@"
  fi
  echo "Testing connection, Wait and send a 'status' cmd, check for 1 or 0 upstream: " $NODE_IP
  runLiveNetDaemon --add-exclusive-node "$NODE_IP"
  ;;

test)
  shift
  echo "Testing connection, Wait and send a 'status' cmd, check for 1 or 0 upstream: " $NODE_IP
  runLiveNetDaemon --add-exclusive-node "$NODE_IP"
  ;;



dev-fund)
  shift
  showDevFund "$@"
  ;;

sh | bash)
  /bin/bash
  ;;

bc-size)
  du -h ./data/livenet/lmdb/data.mdb
  ;;

*)
  echo "Available Commands: "
  echo "sync|daemon|import|export|vpn-rpc|wallet-rpc|make-wallet|wallet-cmd|wallet-cli|testnet|bash"
  exit 2
  ;;

esac
