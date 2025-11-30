# Plano: Debian IaC Stack

## Arquitetura

```
[Bare Metal] ─── Debian 12 Minimal
                    ├── Docker Engine
                    │   ├── Vaultwarden (password manager)
                    │   └── Gitea (git server)
                    └── KVM/QEMU
                        └── OPNsense VM (firewall)
```

## Stack de Ferramentas

| Camada | Ferramenta | Propósito |
|--------|------------|-----------|
| Config Management | Ansible | Provisionar Debian, instalar Docker/KVM |
| Orquestração | Docker Compose | Definir e executar containers |
| Secrets (Etapa 1) | Arquivos `.env` | Credenciais geradas aleatoriamente |
| Secrets (Etapa 2) | Vaultwarden | Centralizar secrets |
| Versionamento | Git local | Controlar playbooks e compose files |

## Estrutura do Projeto (nova branch)

```
selfhost/
├── ansible/
│   ├── inventory.yml          # Host Debian
│   ├── playbooks/
│   │   ├── 00-base.yml        # Debian base (SSH, usuarios)
│   │   ├── 01-docker.yml      # Instalar Docker Engine
│   │   ├── 02-kvm.yml         # Instalar KVM/QEMU/libvirt
│   │   └── 03-deploy-apps.yml # Deploy containers e VMs
│   └── roles/
│       ├── docker/
│       ├── kvm/
│       └── common/
├── docker/
│   ├── vaultwarden/
│   │   ├── docker-compose.yml
│   │   └── .env.example
│   └── gitea/
│       ├── docker-compose.yml
│       └── .env.example
├── vms/
│   └── opnsense/
│       ├── vm-config.xml      # libvirt XML
│       └── README.md
├── scripts/
│   └── generate-secrets.sh    # Gera .env com senhas aleatórias
├── docs/
│   ├── PLAN.md                # Este plano
│   ├── API-REFERENCE.md       # Endpoints e syntax de cada app
│   └── ARCHITECTURE.md        # Diagrama UML
├── AGENTS.md
└── README.md
```

## Etapas de Implementação

### Etapa 1: Deploy Básico (credenciais efêmeras)

**1.1 - Preparação do Projeto**
- Criar branch `debian-stack` limpa
- Estrutura de diretórios
- Script `generate-secrets.sh` para criar `.env` com `openssl rand`

**1.2 - Ansible Base**
- Playbook `00-base.yml`: usuarios, SSH keys, pacotes base (sem firewall)
- Playbook `01-docker.yml`: instalar Docker Engine + Compose
- Playbook `02-kvm.yml`: instalar QEMU/KVM/libvirt

**1.3 - Deploy Vaultwarden**
- `docker-compose.yml` com SQLite (simples)
- Gerar `ADMIN_TOKEN` aleatório
- Acessível em `http://<ip>:8080`

**1.4 - Deploy Gitea**
- `docker-compose.yml` com SQLite
- Gerar credenciais admin aleatórias
- Acessível em `http://<ip>:3000`

**1.5 - Deploy OPNsense**
- Download ISO oficial
- Criar VM via libvirt (2 NICs: WAN + LAN)
- Configuração inicial manual via console

### Etapa 2: Centralizar Secrets (futura)
- Migrar secrets dos `.env` para Vaultwarden
- Scripts buscam secrets via Vaultwarden CLI
- Backup encriptado

### Etapa 3: Integrações (futura)
- Gitea webhook para CI/CD
- OPNsense como gateway da rede
- Avaliar necessidade de SSO

## Documentação Prévia Necessária

Antes de implementar, consultar e documentar em `docs/API-REFERENCE.md`:

| App | Documentar |
|-----|------------|
| Vaultwarden | Variáveis de ambiente, ADMIN_TOKEN format |
| Gitea | API endpoints, OAuth setup, variáveis |
| OPNsense | Requisitos de hardware VM, configuração inicial |

## Decisões de Design

1. **SQLite para DBs iniciais** - simplicidade, sem PostgreSQL/MySQL extra
2. **Sem reverse proxy inicial** - acesso direto por porta, Traefik depois
3. **Sem firewall no host** - OPNsense será o firewall da rede
4. **Ansible vault opcional** - `.env` não versionado é suficiente para Etapa 1

## Próximos Passos

1. Criar branch `debian-stack`
2. Implementar estrutura base e scripts
3. Testar deploy no Debian target

