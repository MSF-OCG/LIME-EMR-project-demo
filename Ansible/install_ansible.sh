#!/bin/bash

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
