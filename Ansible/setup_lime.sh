#!/bin/bash
set -e

# Variables
DEMO="d"
DEV_ENV="D"
QA_ENV="T"
PROD_ENV="P"
INSTALLATION_DIR="/home/lime/setup"
LOG_DIR="/var/logs/lime/setup"
REPO_URL="https://raw.githubusercontent.com/MSF-OCG/LIME-EMR-project-demo/"
BRANCH="dev"
INVENTORY="dev"

# Functions
generate_log_filename() {
    local current_timestamp
    current_timestamp=$(date '+%Y%m%d%H%M%S')
    echo "$LOG_DIR/lime_setup_stderr_${current_timestamp}.log"
}

error_handler() {
    echo "An error occurred. Logging to $(generate_log_filename)" >&2
    echo "Error on line $1" >> $(generate_log_filename)
}

install_ansible() {
    echo "Installing Ansible..."

    if ! command -v ansible &> /dev/null; then
        DEBIAN_FRONTEND=noninteractive apt update
        DEBIAN_FRONTEND=noninteractive apt install -y software-properties-common
        DEBIAN_FRONTEND=noninteractive add-apt-repository --yes --update ppa:ansible/ansible
        DEBIAN_FRONTEND=noninteractive apt install -y ansible

        # Check if Ansible was successfully installed
        if ! command -v ansible &> /dev/null; then
            echo "Error: Failed to install Ansible!" >&2
            exit 1
        fi
    else
        echo "Ansible is already installed."
    fi

    ansible --version
}

download_from_repo() {
    local path=$1
    local destination=$2

    if curl -L --create-dirs --output "$destination" "$REPO_URL/$BRANCH/$path"; then
        echo "Downloaded $path in $destination successfully!"
    else
        echo "Error downloading $path. Please check the URL or your internet connection." >&2
        exit 1
    fi
}

install_LIME() {
    echo "Installing LIME from $BRANCH branch and $INVENTORY Ansibly inventory"
    echo "Downloading Ansible playbooks for LIME"
    
    download_from_repo "Ansible/playbook.yaml" "$INSTALLATION_DIR/playbook.yaml"
    download_from_repo "Ansible/inventories/$INVENTORY.ini" "$INSTALLATION_DIR/inventories/$INVENTORY.ini"
    
    echo "Ansible playbooks ready for execution!"
    
    cd $INSTALLATION_DIR
    if ! ANSIBLE_LOG_PATH=/var/logs/lime/setup/ansible_$(date +"%d%m%Y_%H%M%S").log ansible-playbook -i inventories/"$INVENTORY".ini playbook.yaml; then
        echo "Error: Ansible playbook execution failed!" >&2
        exit 1
    fi
    echo "LIME installation complete and application running!"
}

# Set trap to handle errors
trap 'error_handler $LINENO' ERR

# Main script
mkdir -p "$INSTALLATION_DIR" "$LOG_DIR" "$INSTALLATION_DIR/inventories"

# Get the hostname
CURRENT_HOSTNAME=$(hostname)

# Extract the last letter using regex
ENV_LETTER=$(echo "$(hostname)" | sed 's/.*\(.\)$/\1/')

# Print the env letter
echo "$ENV_LETTER"

case $ENV_LETTER in
    $DEMO|$DEV_ENV) 
        echo "This is the Demo/Dev environment." 
        BRANCH="dev"
        INVENTORY="dev"
        install_ansible
        install_LIME
        ;;
    $QA_ENV) 
        echo "This is the QA/UAT environment." 
        BRANCH="qa"
        INVENTORY="qa"
        install_ansible
        install_LIME
        ;;
    $PROD_ENV) 
        echo "This is the Prod environment." 
        BRANCH="main"
        INVENTORY="prod"
        install_ansible
        install_LIME
        ;;
    *) 
        echo "Hostname doesn't match any known environment ($ENV_LETTER). Error reported in log file." >&2
        echo "Hostname $CURRENT_HOSTNAME not recognized" >> $(generate_log_filename)
        exit 1
        ;;
esac
