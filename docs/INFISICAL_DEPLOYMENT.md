# Infisical Deployment Guide

Este documento descreve o processo de deploy do Infisical em 3 fases.

## Fase 1: Bootstrap via SSH

### Pré-requisitos

1. Container docker-lxc (ID 100) criado e rodando
2. Docker instalado no container
3. IP do container conhecido (obter via `terraform output docker_container_ip`)

### Configuração

1. Adicione as variáveis ao `terraform.tfvars`:

```hcl
docker_host_ip = "192.168.3.115"  # IP do container docker-lxc

# Gerar encryption key: openssl rand -base64 32
infisical_postgres_password = "seu-password-postgres"
infisical_db_password       = "seu-password-db"
infisical_encryption_key     = "sua-chave-base64-32-bytes"
infisical_jwt_signing_key   = "sua-chave-jwt"
```

2. Inicialize e aplique:

```bash
terraform init
terraform plan
terraform apply
```

3. Acesse Infisical:

```
http://<docker-host-ip>:8080
```

### Verificação

```bash
# Verificar containers
ssh root@192.168.3.2 "pct exec 100 -- docker ps"

# Verificar logs
ssh root@192.168.3.2 "pct exec 100 -- docker logs infisical"
```

---

## Fase 2: Geração de Certificados TLS

### Objetivo

Gerar certificados TLS para Docker daemon e Infisical usando Infisical como gerenciador central.

### Passos

1. Gerar certificados:

```bash
./scripts/generate_certs.sh ./certs 192.168.3.115
```

Isso cria:
- `ca.pem`, `ca-key.pem` - Certificate Authority
- `server.pem`, `server-key.pem` - Docker daemon server
- `cert.pem`, `key.pem` - Docker client (Terraform)
- `infisical.pem`, `infisical-key.pem` - Infisical HTTPS

2. Armazenar certificados no Infisical:

Após criar projeto e workspace no Infisical, adicione os certificados como secrets:

```
/certificates/
├── ca.pem
├── ca-key.pem
├── docker-server.pem → server.pem
├── docker-server-key.pem → server-key.pem
├── docker-client.pem → cert.pem
├── docker-client-key.pem → key.pem
├── infisical-server.pem → infisical.pem
└── infisical-server-key.pem → infisical-key.pem
```

3. Configurar Docker daemon para TLS:

```bash
./scripts/configure_docker_tls.sh 192.168.3.2 100 ./certs
```

Isso:
- Copia certificados para `/etc/docker/`
- Configura `daemon.json` para TLS na porta 2376
- Reinicia Docker daemon

---

## Fase 3: Migração para TLS

### Objetivo

Migrar toda comunicação para TCP+TLS, eliminando necessidade de SSH para operações normais.

### Atualização do Terraform

1. Atualizar `providers.tf`:

```hcl
provider "docker" {
  host = "tcp://${var.docker_host_ip}:2376"
  
  # Certificados do Infisical (via data source)
  cert_path = pathexpand("~/.docker/certs")
  # ou usar certificados do Infisical diretamente
}
```

2. Adicionar Infisical provider:

```hcl
provider "infisical" {
  host = "https://${var.docker_host_ip}:8443"
  client_id     = var.infisical_client_id
  client_secret = var.infisical_client_secret
}
```

3. Buscar certificados do Infisical:

```hcl
data "infisical_secrets" "docker_certs" {
  env_slug     = "prod"
  folder_path  = "/certificates"
}

# Usar certificados para Docker provider
```

### Configurar Infisical HTTPS

1. Configurar Infisical para usar certificados TLS:

Atualizar variáveis de ambiente do container Infisical:

```hcl
env = [
  # ... outras variáveis
  "TLS_CERT_PATH=/certs/infisical.pem",
  "TLS_KEY_PATH=/certs/infisical-key.pem",
  "SERVER_URL=https://192.168.3.115:8443"
]
```

2. Mapear certificados como volume:

```hcl
volumes {
  host_path      = "/etc/docker/infisical.pem"
  container_path = "/certs/infisical.pem"
}
```

---

## Resultado Final

| Conexão | Protocolo | Porta | Autenticação |
|---------|-----------|-------|--------------|
| Terraform → Docker | TCP+TLS | 2376 | Certificados client |
| Terraform → Infisical | HTTPS | 8443 | API Token |
| Apps → Infisical | HTTPS | 8443 | API Token |

### Vantagens

- ✅ Comunicação encriptada end-to-end
- ✅ Certificados gerenciados centralmente
- ✅ Rotação automática via Infisical
- ✅ Sem necessidade de SSH para operações normais
- ✅ Audit trail completo

---

## Troubleshooting

### Docker daemon não inicia com TLS

Verificar logs:
```bash
ssh root@192.168.3.2 "pct exec 100 -- journalctl -u docker"
```

Verificar permissões dos certificados:
```bash
ssh root@192.168.3.2 "pct exec 100 -- ls -la /etc/docker/*.pem"
```

### Infisical não acessível via HTTPS

Verificar certificados no container:
```bash
ssh root@192.168.3.2 "pct exec 100 -- docker exec infisical ls -la /certs"
```

Verificar variáveis de ambiente:
```bash
ssh root@192.168.3.2 "pct exec 100 -- docker exec infisical env | grep TLS"
```

