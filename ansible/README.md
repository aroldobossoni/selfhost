# Ansible - OPNsense on Proxmox

Ansible automation for OPNsense firewall deployment on Proxmox VE.

## Quick Start

```bash
cd ansible

# Install Ansible collections
ansible-galaxy collection install -r requirements.yml

# Install Python dependencies
pip install -r requirements.txt

# Configure variables
cp roles/opnsense/defaults/main.yml my-vars.yml
# Edit my-vars.yml with your settings

# Deploy VM
ansible-playbook playbooks/deploy.yml --tags iso,vm -e @my-vars.yml

# After manual installation, restore config
ansible-playbook playbooks/restore.yml -e @my-vars.yml

# Update OPNsense
ansible-playbook playbooks/update.yml -e @my-vars.yml
```

## Documentation

See [roles/opnsense/README.md](roles/opnsense/README.md) for full documentation.

