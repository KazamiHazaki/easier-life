#!/bin/bash

echo "Example: https://lb.drpc.org/ogrpc?network=sepolia&dkey=api_key_XXX"
read -p "Enter new ETHEREUM_HOSTS key: " ETHEREUM_HOSTS

echo "Example: https://lb.drpc.org/rest/api_key_XXX/eth-beacon-chain-sepolia"
read -p "Enter new L1_CONSENSUS_HOST_URLS key: " L1_CONSENSUS_HOST_URL

read -p "Enter new Validator Private Key (starting with 0x): " PRIVATE_KEY
if [[ ! $PRIVATE_KEY =~ ^0x[a-fA-F0-9]{64}$ ]]; then
  echo "❌ Invalid private key format. Should start with '0x' and contain 64 hex chars."
  exit 1
fi

read -p "Enter new Coinbase Wallet Address: " WALLET_ADDR
ETHEREUM_HOSTS_ESCAPED=$(printf '%s' "$ETHEREUM_HOSTS" | sed 's/&/\\&/g')
L1_CONSENSUS_HOST_URL_ESCAPED=$(printf '%s' "$L1_CONSENSUS_HOST_URL" | sed 's/&/\\&/g')


P2P_IP=$(curl -4 -s ifconfig.me)
if [ -z "$P2P_IP" ]; then
  echo "❌ Failed to retrieve public IP. Check your connection."
  exit 1
fi
echo "🌐 Public IP: $P2P_IP"

FILE="$HOME/aztec/docker-compose.yaml"
YAML_PATH="$FILE"

if [ ! -f "$FILE" ]; then
  echo "Creating docker-compose.yaml..."
fi

DIR=$(dirname "$FILE")
[ ! -d "$DIR" ] && mkdir -p "$DIR"
[ ! -s "$FILE" ] && rm -f "$FILE"

if [ ! -f "$YAML_PATH" ]; then
  cat > "$YAML_PATH" <<EOF
name: aztec-sequencer
services:
  aztec-sequencer:
    container_name: aztec-sequencer
    restart: always
    image: aztecprotocol/aztec:alpha-testnet
    environment:
      DATA_DIRECTORY: /data
      ETHEREUM_HOSTS: ""
      L1_CONSENSUS_HOST_URLS: ""
      VALIDATOR_PRIVATE_KEY: ""
      COINBASE: ""
      P2P_IP: ""
      LOG_LEVEL: debug
    entrypoint: >
      sh -c 'node --no-warnings /usr/src/yarn-project/aztec/dest/bin/index.js start --network alpha-testnet start --node --archiver --sequencer'
    ports:
      - 40400:40400/tcp
      - 40400:40400/udp
      - 8080:8080
    volumes:
      - ./data:/data
    healthcheck:
      test: ["CMD", "curl", "-f", "-s", "-X", "POST", "-H", "Content-Type: application/json", "--data", "{\"jsonrpc\":\"2.0\",\"method\":\"node_getNodeInfo\",\"params\":[],\"id\":1}", "http://localhost:8080"]
      interval: 30s
      timeout: 10s
      retries: 5
      start_period: 20s
EOF
  echo "✅ docker-compose.yaml created."
fi

sed -i \
  -e "s|ETHEREUM_HOSTS:.*|ETHEREUM_HOSTS: \"$ETHEREUM_HOSTS_ESCAPED\"|" \
  -e "s|L1_CONSENSUS_HOST_URLS:.*|L1_CONSENSUS_HOST_URLS: \"$L1_CONSENSUS_HOST_URL_ESCAPED\"|" \
  -e "s|VALIDATOR_PRIVATE_KEY:.*|VALIDATOR_PRIVATE_KEY: ${PRIVATE_KEY}|" \
  -e "s|COINBASE:.*|COINBASE: ${WALLET_ADDR}|" \
  -e "s|P2P_IP:.*|P2P_IP: ${P2P_IP}|" \
  "$FILE"

echo "✅ docker-compose.yaml updated."

# Start Docker Compose
docker compose -f "$YAML_PATH" up -d
echo "🚀 aztec-sequencer starting..."

# Wait until the container is healthy
echo "⏳ Waiting for aztec-sequencer container to become healthy..."
for i in {1..30}; do
  STATUS=$(docker inspect --format='{{.State.Health.Status}}' aztec-sequencer 2>/dev/null)
  echo "🔁 Status: $STATUS"
  if [ "$STATUS" == "healthy" ]; then
    echo "✅ Container is healthy!"
    break
  fi
  sleep 5
done

if [ "$STATUS" != "healthy" ]; then
  echo "❌ Container did not become healthy in time. Exiting."
  exit 1
fi

# Once healthy, make the JSON-RPC calls
GREEN='\033[0;32m'
NC='\033[0m'

NODE_SYNC=$(curl -s -X POST -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","method":"node_getL2Tips","params":[],"id":67}' \
  http://localhost:8080 | jq -r ".result.proven.number")

echo -e "${GREEN}Synced Proven Number: $NODE_SYNC${NC}"

ARCHIVE_RESULT=$(curl -s -X POST -H 'Content-Type: application/json' \
  -d "{\"jsonrpc\":\"2.0\",\"method\":\"node_getArchiveSiblingPath\",\"params\":[\"$NODE_SYNC\",\"$NODE_SYNC\"],\"id\":67}" \
  http://localhost:8080 | jq -r ".result")

echo -e "${GREEN}Archive Sibling Path Result:${NC}"
echo -e "${GREEN}$ARCHIVE_RESULT${NC}"
