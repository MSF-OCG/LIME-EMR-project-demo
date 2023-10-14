#!/bin/bash

echo "Installing Ansible..."

# Update the system
apt update

# Install software-properties-common (required for add-apt-repository)
apt install -y software-properties-common

# Add the Ansible PPA
add-apt-repository --yes --update ppa:ansible/ansible

# Install Ansible
apt install -y ansible

# Verify the installation
ansible --version

echo "Ansible installation completed!"

echo "Downloading Ansible playbooks for LIME"

# Downloading files
curl -O -L --create-dirs --output-dir /home/lime/setup/ https://github.com/MSF-OCG/LIME-EMR-project-demo/releases/download/nightly/lime_setup.tar.gz

# Unpacking Ansible playbooks and files
cd /home/lime/setup/ && tar -xzf lime_setup.tar.gz -C /home/lime/setup/

# Removing archive
rm lime_setup.tar.gz

echo "Ansible playbooks ready for execution!"

echo "Installing the LIME application with Ansible playbooks..."

# Starting the LIME installation
cd /home/lime/setup/Ansible && ansible-playbook -i inventories/dev.ini playbook.yaml 

echo "LIME installation complete and application running!"
