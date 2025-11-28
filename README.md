# Selfhost - Proxmox VE Infrastructure as Code

Infraestrutura como código para gerenciar serviços self-hosted no Proxmox VE utilizando Terraform.

## Features

- ✅ LXC containers não-privilegiados com Docker
- ✅ Infisical (secrets management) com bootstrap automatizado
- ✅ Credenciais auto-geradas (senhas, tokens, chaves)
- ✅ IP dinâmico via DHCP (obtido automaticamente da API Proxmox)
- ✅ Machine Identity com Universal Auth
- ✅ Deploy orquestrado via Python

## Pré-requisitos

- Terraform >= 1.14.0
- Python 3.x
- Acesso SSH ao Proxmox VE (chave configurada)
- Token API do Proxmox VE (criado manualmente uma vez, depois auto-gerenciado)

## Quick Start

```bash
# 1. Clonar e configurar
git clone <repo>
cd selfhost
cp terraform.tfvars.example terraform.tfvars

# 2. Editar terraform.tfvars com suas credenciais Proxmox

# 3. Deploy
make apply
```

## Estrutura do Projeto

```
.
├── modules/
│   ├── docker_lxc/           # LXC container com Docker
│   └── infisical/            # Stack Infisical (PostgreSQL, Redis, Infisical)
├── scripts/
│   ├── deploy.py             # Orquestração principal
│   ├── bootstrap_infisical.py # Bootstrap do Infisical
│   ├── utils.py              # Utilitários e cleanup Docker
│   ├── infisical_client.py   # Cliente API Infisical
│   ├── proxmox_token.py      # Gerenciamento de tokens Proxmox
│   └── proxmox_utils.py      # Template download e Docker install
├── docs/
│   ├── ARCHITECTURE.md       # Diagramas e fluxos
│   ├── HARDCODES.md          # Relatório de credenciais
│   └── INFISICAL_DEPLOYMENT.md # Guia de deploy
├── main.tf                   # Configuração principal
├── random.tf                 # Geração de senhas
├── data_container_ip.tf      # IP dinâmico via API
└── Makefile                  # Comandos make
```

## Comandos

| Comando | Descrição |
|---------|-----------|
| `make apply` | Deploy completo (LXC + Infisical + Bootstrap) |
| `make destroy` | Remove toda infraestrutura |
| `make init` | Inicializa Terraform e dependências |
| `make clean` | Remove arquivos temporários |

## Credenciais Auto-Geradas

| Credential | Descrição |
|------------|-----------|
| `docker_lxc_password` | Senha do container LXC |
| `infisical_admin_password` | Senha do admin Infisical |
| `postgres_password` | Senha do PostgreSQL |
| `encryption_key` | Chave AES-256 |
| `jwt_signing_key` | Chave JWT |
| `proxmox_token` | Token Proxmox (rotacionado semanalmente) |

Para ver uma credencial:
```bash
terraform output docker_lxc_password
```

## Token Proxmox Auto-Gerenciado

O projeto gerencia automaticamente o token Proxmox após o Infisical estar operacional:

1. **Primeira execução**: Crie um token manualmente no Proxmox UI e exporte como variáveis de ambiente:
   ```bash
   export TF_VAR_pm_api_token_id="root@pam!bootstrap"
   export TF_VAR_pm_api_token_secret="your-secret"
   ```

2. **Após Infisical**: O sistema cria automaticamente um novo token via SSH e armazena no Infisical

3. **Rotação**: O token é rotacionado automaticamente a cada 7 dias

4. **Reinstalação**: Em um Proxmox novo/virgem, o sistema detecta ausência e cria novo token automaticamente

## Configuração

Edite `terraform.tfvars`:

```hcl
# Proxmox
pm_api_url          = "https://192.168.3.2:8006/api2/json"
pm_api_token_id     = "user@pam!token"
pm_api_token_secret = "your-secret"
pm_node             = "proxmox"
pm_host             = "192.168.3.2"

# SSH
proxmox_ssh_user = "root"
docker_ssh_user  = "root"

# Infisical
enable_infisical      = true
infisical_admin_email = "admin@example.com"
infisical_org_name    = "MyOrg"
infisical_port        = 8080
```

## Outputs

```bash
terraform output docker_container_ip    # IP do container
terraform output infisical_url          # URL do Infisical
terraform output docker_lxc_password    # Senha do LXC (sensitive)
```

## Documentação

- [Architecture](docs/ARCHITECTURE.md) - Diagramas e fluxos
- [Infisical Deployment](docs/INFISICAL_DEPLOYMENT.md) - Guia detalhado
- [Hardcodes Report](docs/HARDCODES.md) - Status das credenciais

## Roadmap

- [ ] Substituir API Token por autenticação SSH
- [ ] Argo CD
- [ ] Authentik (SSO)
- [ ] Grafana + Prometheus
- [ ] Backup automatizado

## Referências

- [Proxmox VE Helper Scripts](https://community-scripts.github.io/ProxmoxVE/)
- [Terraform Provider Proxmox](https://github.com/Telmate/terraform-provider-proxmox)
- [Infisical Documentation](https://infisical.com/docs)
- [Infisical Terraform Provider](https://registry.terraform.io/providers/Infisical/infisical)
