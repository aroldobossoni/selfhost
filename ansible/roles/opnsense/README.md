# OPNsense Ansible Role

Ansible role for deploying and managing OPNsense firewall on Proxmox VE.

## Features

- Automatic ISO download with SHA256 verification
- VM creation with PCI passthrough for network interfaces
- Configuration restore via OPNsense API
- Firmware updates with Proxmox snapshots
- Dynamic VM ID discovery

## Requirements

- Ansible >= 2.14
- Proxmox VE >= 7.0
- IOMMU enabled for PCI passthrough
- OPNsense API keys (for configure/update tasks)
- Infisical server (optional, for secrets management)

## Dependencies

```bash
ansible-galaxy collection install -r requirements.yml
pip install infisicalsdk  # For Infisical integration
```

## Quick Start

### 1. Configure Variables

**Option A: Using Infisical (recommended)**

```bash
# Set environment variables
export INFISICAL_CLIENT_ID="your-client-id"
export INFISICAL_CLIENT_SECRET="your-client-secret"
export INFISICAL_PROJECT_ID="your-project-id"

# Run playbook - credentials are fetched from Infisical
ansible-playbook playbooks/deploy.yml --tags iso,vm
```

**Option B: Manual configuration**

Edit `roles/opnsense/defaults/main.yml` or create a vars file:

```yaml
# Proxmox connection
proxmox_api_host: "192.168.3.2"
proxmox_api_user: "root@pam"
proxmox_api_token_id: "ansible"
proxmox_api_token_secret: "your-token-secret"

# OPNsense API (after installation)
opnsense_api_host: "192.168.3.1"
opnsense_api_key: "your-api-key"
opnsense_api_secret: "your-api-secret"

# Disable Infisical
infisical_enabled: false
```

### 2. Deploy VM

```bash
# Download ISO and create VM
ansible-playbook playbooks/deploy.yml --tags iso,vm
```

### 3. Manual Installation

1. Open Proxmox console for the VM
2. Start the VM
3. Complete OPNsense installation
4. Configure initial network settings
5. Create API keys in System > Access > Users

### 4. Configure and Restore

```bash
# Place your config.xml in roles/opnsense/files/
cp /path/to/backup/config.xml ansible/roles/opnsense/files/

# Restore configuration
ansible-playbook playbooks/restore.yml
```

### 5. Updates

```bash
# Update OPNsense (creates snapshot first)
ansible-playbook playbooks/update.yml
```

## Configuration

### VM Hardware

| Variable | Default | Description |
|----------|---------|-------------|
| `vm_name` | `OPNsense` | VM name (case sensitive) |
| `vm_cores` | `2` | CPU cores |
| `vm_memory` | `3072` | RAM in MB |
| `vm_balloon` | `1024` | Minimum RAM in MB |
| `vm_disk_size` | `32G` | Disk size |
| `vm_bios` | `ovmf` | UEFI boot |
| `vm_machine` | `q35` | Machine type |

### PCI Passthrough

```yaml
pci_passthrough:
  - id: "0000:06:00.0"    # WAN port 1
    rombar: 1
  - id: "0000:06:00.1"    # Port 2
    rombar: 1
  - id: "0000:07:00.0"    # Port 3
    rombar: 1
  - id: "0000:07:00.1"    # Port 4
    rombar: 1
```

### Network

```yaml
vm_net_lan:
  bridge: "vmbr0"
  model: "e1000e"
  tag: null              # VLAN tag (optional)
```

## Playbooks

| Playbook | Description |
|----------|-------------|
| `deploy.yml` | Full deployment (ISO + VM + configure) |
| `update.yml` | Update OPNsense with snapshot |
| `restore.yml` | Restore config.xml |

### Tags

| Tag | Description |
|-----|-------------|
| `iso` | Download and verify ISO |
| `vm` | Create VM on Proxmox |
| `configure` | Configure via API |
| `restore` | Restore config.xml |
| `update` | Update firmware |

## API Keys

After OPNsense installation, create API keys:

1. Access OPNsense web UI
2. Go to System > Access > Users
3. Edit your user or create a new one
4. Generate API keys
5. Save the key and secret

## Directory Structure

```
ansible/
├── ansible.cfg
├── inventory.yml
├── requirements.yml
├── playbooks/
│   ├── deploy.yml
│   ├── update.yml
│   └── restore.yml
└── roles/
    └── opnsense/
        ├── defaults/
        │   └── main.yml      # All configuration here
        ├── files/
        │   └── config.xml    # Your backup (copy here)
        ├── tasks/
        │   ├── main.yml
        │   ├── iso.yml
        │   ├── vm_create.yml
        │   ├── configure.yml
        │   └── update.yml
        ├── templates/
        │   └── vm_args.j2
        └── vars/
            └── main.yml
```

## Infisical Integration

The role can fetch credentials automatically from Infisical:

### Required Secrets in Infisical

| Path | Key | Description |
|------|-----|-------------|
| `/proxmox` | `PROXMOX_TOKEN_ID` | Proxmox API token ID |
| `/proxmox` | `PROXMOX_TOKEN_SECRET` | Proxmox API token secret |
| `/opnsense` | `OPNSENSE_API_KEY` | OPNsense API key (optional) |
| `/opnsense` | `OPNSENSE_API_SECRET` | OPNsense API secret (optional) |

### Configuration Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `infisical_enabled` | `true` | Enable Infisical lookup |
| `infisical_url` | `http://192.168.3.115:8080` | Infisical server URL |
| `infisical_project_id` | `""` | Project ID |
| `infisical_env_slug` | `prod` | Environment (dev/staging/prod) |
| `infisical_proxmox_path` | `/proxmox` | Path to Proxmox secrets |
| `infisical_opnsense_path` | `/opnsense` | Path to OPNsense secrets |

## Troubleshooting

### PCI Passthrough not working

1. Verify IOMMU is enabled: `dmesg | grep -e DMAR -e IOMMU`
2. Check device IDs: `lspci -nn`
3. Ensure devices are bound to vfio-pci

### API connection failed

1. Verify OPNsense is running
2. Check API keys are correct
3. Ensure firewall allows API access
4. Try with `opnsense_api_validate_certs: false`

### ISO download failed

1. Check internet connectivity
2. Verify mirror URL is accessible
3. Try alternative mirror

## License

MIT

