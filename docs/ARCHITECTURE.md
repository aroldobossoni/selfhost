# Architecture

## Infrastructure Diagram

```mermaid
flowchart TB
    subgraph User["User Environment"]
        TF[("terraform apply")]
        TFVARS["terraform.tfvars<br/>(credentials)"]
    end

    subgraph Terraform["Terraform Configuration"]
        MAIN["main.tf"]
        PROVIDERS["providers.tf"]
        VARS["variables.tf"]
        VERSIONS["versions.tf"]
        
        subgraph Module["module: docker_lxc"]
            M_MAIN["main.tf"]
            M_VARS["variables.tf"]
            M_OUT["outputs.tf"]
        end
    end

    subgraph Scripts["Shell Scripts"]
        DL_SCRIPT["download_template.sh"]
        INST_SCRIPT["install_docker.sh"]
    end

    subgraph Proxmox["Proxmox VE (192.168.3.2)"]
        API["API :8006"]
        SSH["SSH :22"]
        
        subgraph Node["Node: pve"]
            STORAGE[("Storage<br/>local / local-zfs")]
            TEMPLATE["Alpine Template"]
            
            subgraph LXC["LXC Container"]
                DOCKER["Docker Engine"]
                COMPOSE["Docker Compose"]
            end
        end
    end

    TF --> TFVARS
    TF --> MAIN
    MAIN --> PROVIDERS
    MAIN --> VARS
    MAIN --> Module
    
    PROVIDERS -->|"API Token"| API
    
    M_MAIN -->|"null_resource"| DL_SCRIPT
    M_MAIN -->|"proxmox_lxc"| API
    M_MAIN -->|"null_resource"| INST_SCRIPT
    
    DL_SCRIPT -->|"pveam download"| SSH
    INST_SCRIPT -->|"pct exec"| SSH
    
    SSH --> TEMPLATE
    SSH --> LXC
    API --> STORAGE
    API --> LXC
    
    TEMPLATE --> LXC
    LXC --> DOCKER
    DOCKER --> COMPOSE
```

## Execution Flow

```mermaid
sequenceDiagram
    autonumber
    participant U as User
    participant TF as Terraform
    participant API as Proxmox API
    participant SSH as Proxmox SSH
    participant LXC as LXC Container

    U->>TF: terraform apply
    TF->>TF: Load variables from terraform.tfvars
    
    rect rgb(40, 40, 60)
        Note over TF,SSH: Phase 1: Download Template
        TF->>SSH: null_resource: download_template.sh
        SSH->>SSH: pveam list (check if exists)
        SSH->>SSH: pveam download (if needed)
    end

    rect rgb(40, 60, 40)
        Note over TF,LXC: Phase 2: Create Container
        TF->>API: proxmox_lxc.docker
        API->>LXC: Create LXC (Alpine)
        API->>LXC: Configure: cores, memory, network
        API->>LXC: Start container
    end

    rect rgb(60, 40, 40)
        Note over TF,LXC: Phase 3: Install Docker
        TF->>SSH: null_resource: install_docker.sh
        SSH->>LXC: pct exec: apk update
        SSH->>LXC: pct exec: apk add docker
        SSH->>LXC: pct exec: rc-update add docker
        SSH->>LXC: pct exec: service docker start
    end

    TF->>U: Output: container_id, hostname, ip
```

## Component Overview

| Component | Purpose |
|-----------|---------|
| `main.tf` | Root module configuration, instantiates docker_lxc module |
| `providers.tf` | Proxmox provider configuration with API credentials |
| `variables.tf` | Input variables for Docker LXC configuration |
| `modules/docker_lxc/` | Reusable module for LXC containers with Docker |
| `scripts/download_template.sh` | Downloads Alpine template via SSH if not present |
| `scripts/install_docker.sh` | Installs Docker inside LXC container via pct exec |

