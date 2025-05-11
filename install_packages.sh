#!/bin/bash

# Script to install essential packages on Ubuntu 24.04
# Run with sudo: sudo bash install_packages.sh

# Log file
LOG_FILE="/var/log/install_packages.log"
exec > >(tee -a "$LOG_FILE") 2>&1

# Function to log messages
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    log "ERROR: This script must be run as root. Use sudo."
    exit 1
fi

# Update and upgrade system packages
log "Updating and upgrading system packages..."
apt-get update && apt-get upgrade -y || {
    log "ERROR: Failed to update/upgrade packages."
    exit 1
}

# Install main packages
log "Installing main packages..."
apt install -y curl iptables build-essential git wget lz4 jq make gcc nano automake autoconf tmux htop nvme-cli pkg-config libssl-dev libleveldb-dev tar clang bsdmainutils ncdu unzip || {
    log "ERROR: Failed to install main packages."
    exit 1
}

# Install Python3 and pip
log "Installing Python3 and pip..."
apt install -y python3-pip python3-dev build-essential libssl-dev libffi-dev || {
    log "ERROR: Failed to install Python3 and pip."
    exit 1
}
echo "Skipping pip upgrade due to PEP 668"

# Install Go
log "Installing Go 1.22.3..."
rm -rf /usr/local/go
curl -L https://go.dev/dl/go1.22.3.linux-amd64.tar.gz | tar -xzf - -C /usr/local || {
    log "ERROR: Failed to download or extract Go."
    exit 1
}
echo 'export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin' >> $HOME/.bash_profile
source $HOME/.bash_profile
go version || {
    log "ERROR: Go installation failed."
    exit 1
}

# Install Node.js 18, npm, and yarn
log "Checking Node.js version..."
NODE_VERSION=$(node --version 2>/dev/null | grep -oP 'v\K\d+')
if [[ "$NODE_VERSION" != "18" ]]; then
    log "Installing Node.js 18..."
    apt-get remove -y nodejs
    apt-get purge -y nodejs
    apt-get autoremove -y
    rm -f /etc/apt/keyrings/nodesource.gpg /etc/apt/sources.list.d/nodesource.list

    NODE_MAJOR=18
    apt-get update
    apt-get install -y ca-certificates curl gnupg
    mkdir -p /etc/apt/keyrings
    curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg || {
        log "ERROR: Failed to set up Node.js GPG key."
        exit 1
    }
    echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_${NODE_MAJOR}.x nodistro main" | tee /etc/apt/sources.list.d/nodesource.list
    apt-get update
    apt-get install -y nodejs || {
        log "ERROR: Failed to install Node.js."
        exit 1
    }
    node --version
else
    log "Node.js 18 already installed, skipping..."
fi

log "Installing npm..."
apt-get install -y npm || {
    log "ERROR: Failed to install npm."
    exit 1
}
npm --version

log "Installing yarn..."
curl -sSL https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - || {
    log "ERROR: Failed to add yarn GPG key."
    exit 1
}
echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list
apt-get update -y
apt-get install -y yarn || {
    log "ERROR: Failed to install yarn."
    exit 1
}

# Install Docker and Docker Compose
log "Installing Docker and Docker Compose..."
apt update -y && apt upgrade -y
for pkg in docker.io docker-doc docker-compose podman-docker containerd runc; do
    apt-get remove -y $pkg 2>/dev/null
done

apt-get install -y ca-certificates curl gnupg
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg || {
    log "ERROR: Failed to set up Docker GPG key."
    exit 1
}
chmod a+r /etc/apt/keyrings/docker.gpg
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
apt update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin || {
    log "ERROR: Failed to install Docker."
    exit 1
}

# Test Docker
log "Testing Docker installation..."
docker run hello-world || {
    log "ERROR: Docker test failed."
    exit 1
}

log "Installation completed successfully!"
