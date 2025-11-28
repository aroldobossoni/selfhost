# Infisical Deployment Guide

Deploy automatizado do Infisical via `make apply`.

## Pré-requisitos

1. Terraform >= 1.14.0
2. Python 3.x com venv
3. Acesso SSH ao Proxmox (chave configurada)
4. Token API do Proxmox

## Quick Start

```bash
# 1. Configurar variáveis
cp terraform.tfvars.example terraform.tfvars
# Editar terraform.tfvars com suas credenciais

# 2. Habilitar Infisical
# Em terraform.tfvars:
enable_infisical = true

# 3. Deploy completo
make apply
```

## Fluxo de Deploy

O `make apply` executa automaticamente:

### Phase 1: LXC Container
- Cria container LXC não-privilegiado
- Instala Docker e SSH
- Obtém IP via API Proxmox

### Phase 2: Infisical Stack
- PostgreSQL 15 (Alpine)
- Redis 7 (Alpine)
- Infisical (latest)

### Phase 3: Bootstrap
- Cria usuário admin
- Cria organização
- Gera token de acesso
- Salva em `infisical_bootstrap.auto.tfvars`

### Phase 4: Machine Identity
- Cria Machine Identity para Terraform
- Configura Universal Auth
- Gera Client ID/Secret
- Salva em `infisical_token.auto.tfvars`

## Credenciais Auto-Geradas

| Credential | Como obter |
|------------|------------|
| Docker LXC password | `terraform output docker_lxc_password` |
| Infisical admin password | `terraform state pull \| jq ...` |
| Infisical URL | `terraform output infisical_url` |
| Container IP | `terraform output docker_container_ip` |

## Verificação

```bash
# Status dos containers
DOCKER_IP=$(terraform output -raw docker_container_ip)
ssh root@$DOCKER_IP "docker ps"

# Logs do Infisical
ssh root@$DOCKER_IP "docker logs infisical --tail 50"

# API status
curl http://$DOCKER_IP:8080/api/status
```

## Acesso Web

- **URL**: `http://<docker_container_ip>:8080`
- **Email**: Configurado em `infisical_admin_email`
- **Senha**: Auto-gerada (ver `terraform state pull`)

## Troubleshooting

### Container não inicia
```bash
ssh root@192.168.3.2 "pct status 100"
ssh root@192.168.3.2 "pct start 100"
```

### Docker não responde
```bash
ssh root@$DOCKER_IP "service docker status"
ssh root@$DOCKER_IP "service docker start"
```

### Infisical não acessível
```bash
ssh root@$DOCKER_IP "docker logs infisical"
ssh root@$DOCKER_IP "docker logs infisical-postgres"
ssh root@$DOCKER_IP "docker logs infisical-redis"
```

## Destroy

```bash
make destroy
```

Remove:
1. Recursos Infisical do state
2. Containers Docker
3. LXC container
4. Arquivos `.auto.tfvars`
