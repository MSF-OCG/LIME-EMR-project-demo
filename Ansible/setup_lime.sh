#!/bin/bash

# Define URL variables for each environment
REPO_URL="https://raw.githubusercontent.com/MSF-OCG/LIME-EMR-project-demo/"
DEV_branch="dev"
QA_branch="qa"
PROD_branch="main"
INSTALLATION_DIR="/home/lime/setup/Ansible/"

set -e

echo "Installing Ansible..."

# Add the Ansible PPA
add-apt-repository --yes --update ppa:ansible/ansible

# Update the system
apt update

# Install software-properties-common (required for add-apt-repository)
apt install -y software-properties-common

# Install Ansible
apt install -y ansible

# Verify the installation
ansible --version

echo "Ansible installation completed!"

echo "Downloading Ansible playbooks for LIME"

# Prompt user for environment selection
echo "Please select an environment:"
select env in "DEV" "QA" "PROD"; do
    case $env in
        DEV ) 
            branch=$DEV_branch
            break
            ;;
        QA ) 
            branch=$QA_branch
            break
            ;;
        PROD ) 
            branch=$PROD_branch
            break
            ;;
        * ) 
            echo "Invalid selection. Please choose a valid option."
            ;;
    esac
done

# Download the selected playbook
echo "Downloading playbook from LIME $branch..."
if curl -L --create-dirs --output $INSTALLATION_DIR/playbook.yaml "$REPO_URL/$branch/Ansible/playbook.yaml"; then
    echo "Playbook downloaded successfully!"
else
    echo "Error downloading playbook. Please check the URL or your internet connection."
    exit 1
fi

# Download the associated inventory
echo "Downloading inventory from LIME $branch..."
if curl -L --create-dirs --output $INSTALLATION_DIR/inventories/"$branch".ini "$REPO_URL/$branch/Ansible/inventories/$branch.ini"; then
    echo "Inventory downloaded successfully!"
else
    echo "Error downloading Inventory. Please check the URL or your internet connection."
    exit 1
fi

echo "Ansible playbooks ready for execution!"

echo "Installing the LIME application with Ansible playbooks..."

# Starting the LIME installation
cd /home/lime/setup/Ansible && ansible-playbook -i inventories/"$branch".ini playbook.yaml 

echo "LIME installation complete and application running!"
