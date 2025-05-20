#!/bin/bash

echo "Example: https://lb.drpc.org/ogrpc?network=sepolia&dkey=api_key_XXX"
read -p "Enter new ETHEREUM_HOSTS key:" ETHEREUM_HOSTS

echo "Example: https://lb.drpc.org/rest/api_key_XXX/eth-beacon-chain-sepolia"
read -p "Enter new L1_CONSENSUS_HOST_URLS key:" L1_CONSENSUS_HOST_URL

read -p "Enter new Validator Private Key (starting with 0x):" PRIVATE_KEY
if [[ ! $PRIVATE_KEY =~ ^0x[a-fA-F0-9]{64}$ ]]; then
  echo "Invalid private key format. Please ensure it starts with '0x' and is followed by 64 hexadecimal characters."
  exit 1
fi

read -p "Enter new Coinbase Wallet Address:" WALLET_ADDR

P2P_IP=$(curl -4 ifconfig.me)
if [ -z "$P2P_IP" ]; then
  echo "Failed to retrieve public IP address. Please check your network connection."
  exit 1
fi
echo "Your public IP address is: $P2P_IP"
echo "This will be used as the P2P_IP in the docker-compose.yaml file."

# Path to docker-compose.yaml
FILE="$HOME/aztec/docker-compose.yaml"
YAML_PATH="$HOME/aztec/docker-compose.yaml"
# Check if the file exists
if [ ! -f "$FILE" ]; then
  echo "File $FILE does not exist. Creating a new one."
fi
# Check if the directory exists
DIR=$(dirname "$FILE")
if [ ! -d "$DIR" ]; then
  echo "Directory $DIR does not exist. Creating it."
  mkdir -p "$DIR"
fi
# Check if the file is empty    
if [ ! -s "$FILE" ]; then
  echo "File $FILE is empty. Creating a new one."
  rm -f "$FILE"
fi

# Create file if missing
if [ ! -f "$YAML_PATH" ]; then
  mkdir -p aztec
  cat > "$YAML_PATH" <<EOF
name: aztec-sequencer
services:
  aztec-sequencer:
    container_name: aztec-sequencer
    restart: always
    image: aztecprotocol/aztec:alpha-testnet
#    network_mode: host
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
      test: ["CMD", "curl", "-f", "-s", "-X", "POST", "-H", "Content-Type: application/json", "--data", '{"jsonrpc":"2.0","method":"node_getNodeInfo","params":[],"id":1}', "http://localhost:8080"]
      interval: 30s
      timeout: 10s
      retries: 5
      start_period: 20s
EOF
  echo "✅ Created default docker-compose.yaml"
fi

# Apply replacements
sed -i \
  -e "s|ETHEREUM_HOSTS:.*|ETHEREUM_HOSTS: \"$ETHEREUM_HOSTS\"|" \
  -e "s|L1_CONSENSUS_HOST_URLS:.*|L1_CONSENSUS_HOST_URLS: \"$L1_CONSENSUS_HOST_URL\"|" \
  -e "s|VALIDATOR_PRIVATE_KEY:.*|VALIDATOR_PRIVATE_KEY: ${PRIVATE_KEY}|" \
  -e "s|COINBASE:.*|COINBASE: ${WALLET_ADDR}|" \
  -e "s|P2P_IP:.*|P2P_IP: ${P2P_IP}|" \
  "$FILE"

echo "✅ aztec/docker-compose.yaml updated successfully."


docker compose -f "$YAML_PATH" up -d
echo "✅ aztec-sequencer started successfully."
