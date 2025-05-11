#!/bin/bash

# Script to install or update essential packages on Ubuntu 24.04
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

# Function to check if a package is installed
is_package_installed() {
    dpkg -l "$1" &> /dev/null
    return $?
}

# Install or update main packages
log "Installing or updating main packages..."
for pkg in curl iptables build-essential git wget lz4 jq make gcc nano automake autoconf tmux htop nvme-cli pkg-config libssl-dev libleveldb-dev tar clang bsdmainutils ncdu unzip; do
    if is_package_installed "$pkg"; then
        log "$pkg is already installed, checking for updates..."
        apt-get install --only-upgrade -y "$pkg" || log "WARNING: Failed to update $pkg."
    else
        log "Installing $pkg..."
        apt-get install -y "$pkg" || {
            log "ERROR: Failed to install $pkg."
            exit 1
        }
    fi
done

# Install or update Python3 and pip
log "Checking Python3 and pip..."
if is_package_installed python3; then
    log "Python3 is already installed, checking for updates..."
    apt-get install --only-upgrade -y python3 python3-pip python3-dev libssl-dev libffi-dev || log "WARNING: Failed to update Python3 packages."
else
    log "Installing Python3 and pip..."
    apt-get install -y python3-pip python3-dev libssl-dev libffi-dev || {
        log "ERROR: Failed to install Python3 and pip."
        exit 1
    }
fi
echo "Skipping pip upgrade due to PEP 668"

# Install or update Go
desired_go_version="1.22.3"
log "Checking Go installation..."
if command -v go >/dev/null 2>&1; then
    current_go_version=$(go version | awk '{print $3}' | sed 's/go//')
    if [[ "$current_go_version" == "$desired_go_version" ]]; then
        log "Go $desired_go_version is already installed."
    else
        log "Updating Go to $desired_go_version..."
        rm -rf /usr/local/go
        curl -L https://go.dev/dl/go${desired_go_version}.linux-amd64.tar.gz | tar -xzf - -C /usr/local || {
            log "ERROR: Failed to download or extract Go."
            exit 1
        }
        echo 'export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin' >> $HOME/.bash_profile
        source $HOME/.bash_profile
        go version || {
            log "ERROR: Go update failed."
            exit 1
        }
    fi
else
    log "Installing Go $desired_go_version..."
    rm -rf /usr/local/go
    curl -L https://go.dev/dl/go${desired_go_version}.linux-amd64.tar.gz | tar -xzf - -C /usr/local || {
        log "ERROR: Failed to download or extract Go."
        exit 1
    }
    echo 'export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin' >> $HOME/.bash_profile
    source $HOME/.bash_profile
    go version || {
        log "ERROR: Go installation failed."
        exit 1
    }
fi

# Install or update Node.js, npm, and yarn
log "Checking Node.js installation..."
if command -v node >/dev/null 2>&1; then
    log "Node.js is already installed, checking for updates..."
    apt-get update
    apt-get install --only-upgrade -y nodejs || log "WARNING: Failed to update Node.js."
else
    log "Installing latest Node.js..."
    apt-get remove -y nodejs 2>/dev/null
    apt-get purge -y nodejs 2>/dev/null
    apt-get autoremove -y 2>/dev/null
    rm -f /etc/apt/keyrings/nodesource.gpg /etc/apt/sources.list.d/nodesource.list

    apt-get install -y ca-certificates curl gnupg
    mkdir -p /etc/apt/keyrings
    curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - || {
        log "ERROR: Failed to set up Node.js repository."
        exit 1
    }
    apt-get update
    apt-get install -y nodejs || {
        log "ERROR: Failed to install Node.js."
        exit 1
    }
fi
node --version

log "Checking npm installation..."
if command -v npm >/dev/null 2>&1; then
    log "npm is already installed, checking for updates..."
    apt-get install --only-upgrade -y npm || log "WARNING: Failed to update npm."
else
    log "Installing npm..."
    apt-get install -y npm || {
        log "ERROR: Failed to install npm."
        exit 1
    }
fi
npm --version

log "Checking yarn installation..."
if command -v yarn >/dev/null 2>&1; then
    log "yarn is already installed, checking for updates..."
    npm install -g yarn || log "WARNING: Failed to update yarn."
else
    log "Installing yarn..."
    curl -sSL https://dl.yarnpkg.com/debian/pubkey.gpg | gpg --dearmor -o /etc/apt/keyrings/yarn.gpg || {
        log "ERROR: Failed to add yarn GPG key."
        exit 1
    }
    echo "deb [signed-by=/etc/apt/keyrings/yarn.gpg] https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list
    apt-get update -y
    apt-get install -y yarn || {
        log "ERROR: Failed to install yarn."
        exit 1
    }
fi

# Install or update Docker and Docker Compose
log "Checking Docker installation..."
if command -v docker >/dev/null 2>&1; then
    log "Docker is already installed, checking for updates..."
    apt-get update
    apt-get install --only-upgrade -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin || log "WARNING: Failed to update Docker."
else
    log "Installing Docker and Docker Compose..."
    apt-get update -y && apt-get upgrade -y
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
    apt-get update -y
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin || {
        log "ERROR: Failed to install Docker."
        exit 1
    }
fi

# Test Docker
log "Testing Docker installation..."
docker run hello-world || {
    log "ERROR: Docker test failed."
    exit 1
}

log "Installation and updates completed successfully!"
