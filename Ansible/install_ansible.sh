#!/bin/bash

# Update the system
sudo apt update

# Install software-properties-common (required for add-apt-repository)
sudo apt install -y software-properties-common

# Add the Ansible PPA
sudo add-apt-repository --yes --update ppa:ansible/ansible

# Install Ansible
sudo apt install -y ansible

# Verify the installation
ansible --version

echo "Ansible installation completed!"
