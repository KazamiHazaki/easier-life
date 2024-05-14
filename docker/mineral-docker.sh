#!/usr/bin/env bash

# Function to check if Docker is installed
check_docker() {
  if ! command -v docker &> /dev/null; then
    echo "Docker not found. Installing Docker..."
    curl -sSL https://raw.githubusercontent.com/KazamiHazaki/simple-script/main/bash-script/install-docker.sh | bash
  else
    echo "Docker is already installed."
  fi
}

echo '================================================='
echo -e "Preparing Your Docker"
echo '================================================='
sleep 3

# Check and install Docker if necessary
check_docker

# Create the directory for the application
mkdir -p $HOME/mineral-app
echo '================================================='
echo -e "Preparing your miner"
echo '================================================='
sleep 3

# Prompt for the number of miners
read -p "How many miners will you create? " NUM_MINERS

echo '================================================='
echo -e "Creating compose docker"
echo '================================================='
sleep 3
# Initialize Docker Compose file
COMPOSE_FILE="$HOME/mineral-app/docker-compose.yml"
echo "version: '3'" > $COMPOSE_FILE
echo "services:" >> $COMPOSE_FILE

# Loop to create entries for each miner
for ((i=1; i<=NUM_MINERS; i++))
do
  read -p "Enter the private key for miner $i: " MINING_PK

  echo '================================================='
  echo -e "Your PK for miner $i: \e[1m\e[32m$MINING_PK\e[0m"
  echo '================================================='
  sleep 3

  # Add the service configuration to the Docker Compose file
  echo "  mineral-app-$i:" >> $COMPOSE_FILE
  echo "    container_name: mineral-app-$i" >> $COMPOSE_FILE
  echo "    image: demonpocong/mineral-app:1" >> $COMPOSE_FILE
  echo "    restart: always" >> $COMPOSE_FILE
  echo "    environment:" >> $COMPOSE_FILE
  echo "      - WALLET=$MINING_PK" >> $COMPOSE_FILE
done

echo '================================================='
echo -e "Running your money maker"
echo '================================================='
sleep 3
# Navigate to the directory and run Docker Compose
cd mineral-app
docker compose up -d

echo '================================================='
echo -e "Check your miner with \e[1m\e[32mdocker compose -f $HOME/mineral-app/docker-compose.yml logs -f\e[0m"
echo '================================================='
sleep 3
