#!/bin/bash
set -e

# Variables
DEMO="azeuwocgomr01d"
DEV_ENV="GCH555VLIME001D"
QA_ENV="GCH555VLIME001T"
UAT_ENV="GCH001VLIME001P"
INSTALLATION_DIR="/home/lime/setup"
LOG_DIR="/var/logs/lime/setup"
REPO_URL="https://raw.githubusercontent.com/MSF-OCG/LIME-EMR-project-demo/"
BRANCH="dev"

# Functions
generate_log_filename() {
    local current_timestamp
    current_timestamp=$(date '+%Y%m%d%H%M%S')
    echo "$LOG_DIR/lime_setup_stderr_${current_timestamp}.log"
}

install_ansible() {
    echo "Installing Ansible..."

    if ! command -v ansible &> /dev/null; then
        apt update
        apt install -y software-properties-common
        add-apt-repository --yes --update ppa:ansible/ansible
        apt install -y ansible
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
    echo "Installing LIME..."
    echo "Downloading Ansible playbooks for LIME"
    
    download_from_repo "Ansible/playbook.yaml" "$INSTALLATION_DIR/playbook.yaml"
    download_from_repo "Ansible/inventories/$BRANCH.ini" "$INSTALLATION_DIR/inventories/$BRANCH.ini"
    
    echo "Ansible playbooks ready for execution!"
    
    cd $INSTALLATION_DIR
    if ! ansible-playbook -i inventories/"$BRANCH".ini playbook.yaml; then
        echo "Error: Ansible playbook execution failed!" >&2
        exit 1
    fi
    echo "LIME installation complete and application running!"
}

# Set trap to ensure ansible installation upon exit
trap 'install_LIME' EXIT

# Main script
mkdir -p "$INSTALLATION_DIR" "$LOG_DIR" "$INSTALLATION_DIR/inventories"
exec 2>$(generate_log_filename)
CURRENT_HOSTNAME=$(hostname)

case $CURRENT_HOSTNAME in
    $DEMO|$DEV_ENV) 
        echo "This is the $CURRENT_HOSTNAME environment." 
        BRANCH="dev"
        ;;
    $QA_ENV) 
        echo "This is the QA environment." 
        BRANCH="qa"
        ;;
    $UAT_ENV) 
        echo "This is the UAT environment." 
        BRANCH="main"
        ;;
    *) 
        echo "Hostname doesn't match any known environment. Error reported in log file and setup stopped." >&2
        exit 1
        ;;
esac

echo "Current repository branch is: $BRANCH"

install_ansible
