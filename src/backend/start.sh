#!/bin/bash

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
RESET='\033[0m'

echo -e "${BLUE}Checking if dfx is already running...${RESET}"

# Check if dfx is already running on port 4943
if lsof -i :4943 &>/dev/null; then
    echo -e "${YELLOW}dfx is already running on port 4943. Stopping existing instance...${RESET}"
    dfx stop
    sleep 1
else
    echo -e "${GREEN}dfx is not running. Proceeding...${RESET}"
fi

echo -e "${BLUE}Starting dfx in the background...${RESET}"
dfx start --background

# Wait a bit to ensure dfx starts properly
sleep 5

echo -e "${BLUE}Checking if 'default' identity already exists...${RESET}"
if ! dfx identity list | grep -q "^default$"; then
    echo -e "${YELLOW}Creating 'default' identity...${RESET}"
    dfx identity new default
else
    echo -e "${GREEN}'default' identity already exists.${RESET}"
fi

echo -e "${BLUE}Switching to 'default' identity...${RESET}"
dfx identity use default

echo -e "${GREEN}Setup complete!${RESET}"




USER=$(whoami)
echo -e "${GREEN}Deleting node1, node2 and node3 from ~/.calimero${RESET}"
rm -rf /Users/${USER}/.calimero/node1
rm -rf /Users/${USER}/.calimero/node2
rm -rf /Users/${USER}/.calimero/node3

echo -e "${GREEN}Compiling context, proxy, and external canister...${RESET}"
bash context/build.sh
bash proxy_contract/build.sh
bash external_contract/build.sh

# Check if devnet is running on port 4943
lsof -i :4943 > /dev/null
if [ $? -ne 0 ]; then
  echo -e "${GREEN}Starting local devnet...${RESET}"
  dfx start --clean --background
fi


# dfx canister call context hello > /dev/null 2>&1
# if [ $? -ne 0 ]; then
#   echo -e "${GREEN}Uploading WASM for context canister...${RESET}"
#   dfx canister install context --mode=install --wasm ./context/res/kv_store.wasm
#   dfx canister call context hello > /dev/null 2>&1
#   if [ $? -ne 0 ]; then
#     echo -e "${RED}ERROR: could not reach context canister.${RESET}"
#     exit 1
#   fi
# fi


# Create proxy canister
dfx canister id proxy_contract > /dev/null
if [ $? -ne 0 ]; then
  echo -e "${GREEN}Creating proxy canister...${RESET}"
  dfx canister create proxy_contract
fi
dfx canister call proxy_contract cycles_left > /dev/null 2>&1
if [ $? -ne 0 ]; then
  echo -e "${GREEN}Uploading WASM for proxy canister...${RESET}"
  dfx canister install proxy_contract --mode=install --wasm ./proxy_contract/res/proxy_contract.wasm
  dfx canister call proxy_contract cycles_left > /dev/null 2>&1
  if [ $? -ne 0 ]; then
    echo -e "${RED}ERROR: could not reach proxy canister.${RESET}"
    exit 1
  fi
fi

# Fetch proxy canister ID and echo
PROXY_CANISTER_ID=$(dfx canister id proxy_contract)
echo -e "${GREEN}Proxy Canister ID: ${PROXY_CANISTER_ID}${RESET}"

# Create external canister
dfx canister id external_contract > /dev/null
if [ $? -ne 0 ]; then
  echo -e "${GREEN}Creating external canister...${RESET}"
  dfx canister create external_contract
fi
dfx canister call external_contract hello > /dev/null 2>&1
if [ $? -ne 0 ]; then
  echo -e "${GREEN}Uploading WASM for external canister...${RESET}"
  dfx canister install external_contract --mode=install --wasm ./external_contract/res/external_contract.wasm
  dfx canister call external_contract hello > /dev/null 2>&1
  if [ $? -ne 0 ]; then
    echo -e "${RED}ERROR: could not reach external canister.${RESET}"
    exit 1
  fi
fi

# Fetch external canister ID and echo
EXTERNAL_CANISTER_ID=$(dfx canister id external_contract)
echo -e "${GREEN}External Canister ID: ${EXTERNAL_CANISTER_ID}${RESET}"

# Save to .env file
echo -e "${GREEN}Saving canister IDs to .env file...${RESET}"
echo "PROXY_CANISTER_ID=${PROXY_CANISTER_ID}" >> .env
echo "EXTERNAL_CANISTER_ID=${EXTERNAL_CANISTER_ID}" >> .env

echo -e "${GREEN}Installation done! Starting node${RESET}"


echo -e "${BLUE}Initializing nodes${RESET}"

# Initialize Node 1
NODE1_PEERID=$(merod --node-name node1 init --server-port 2427 --swarm-port 2527 | grep "Generated identity" | sed -E 's/.*PeerId\("(.*)"\)/\1/')
echo "Node 1 PeerId: $NODE1_PEERID"
echo "NODE1_PEERID=$NODE1_PEERID" >> .env

# Initialize Node 2
NODE2_PEERID=$(merod --node-name node2 init --server-port 2428 --swarm-port 2528 | grep "Generated identity" | sed -E 's/.*PeerId\("(.*)"\)/\1/')
echo "Node 2 PeerId: $NODE2_PEERID"
echo "NODE2_PEERID=$NODE2_PEERID" >> .env

# Initialize Node 3
NODE3_PEERID=$(merod --node-name node3 init --server-port 2429 --swarm-port 2529 | grep "Generated identity" | sed -E 's/.*PeerId\("(.*)"\)/\1/')
echo "Node 3 PeerId: $NODE3_PEERID"
echo "NODE3_PEERID=$NODE3_PEERID" >> .env

# Done
echo "All nodes initialized and PeerIds saved in existing.env"
