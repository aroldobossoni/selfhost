# AGENTS.md - Documentação para Agentes de IA

Informações essenciais para agentes de IA trabalharem neste projeto.

## Contexto do Projeto

Infraestrutura como código usando Terraform para gerenciar serviços self-hosted no Proxmox VE.

## Estrutura

```
modules/
├── docker_lxc/     # LXC container com Docker (unprivileged)
└── infisical/      # Stack Infisical (PostgreSQL, Redis, Infisical)

scripts/
├── deploy.py             # Orquestração principal
├── bootstrap_infisical.py
├── utils.py              # Utilitários e cleanup Docker
├── infisical_client.py
├── proxmox_token.py      # Gerenciamento de tokens Proxmox
└── proxmox_utils.py      # Template download e Docker install
```

## Convenções

- **Idioma**: Código, variáveis e comentários em inglês
- **Nomenclatura**: `snake_case` para tudo
- **Modularização**: Módulos pequenos e focados
- **Sem hardcode**: Usar variáveis e `random_password`

## Divisão de Responsabilidades

### Terraform (prioridade)
- Provisionar infraestrutura (LXC, Docker, containers)
- Gerenciar recursos Infisical (`infisical_identity`, `infisical_project`, `infisical_secret`)
- Gerar credenciais (`random_password`, `random_bytes`)
- Obter IP dinâmico (`data.http` → Proxmox API)

### Python (scripts/)
- **Bootstrap**: Operações sem resource Terraform (ex: `/api/v1/admin/bootstrap`)
- **Orquestração**: `deploy.py` coordena fases
- **Utilitários**: Funções reutilizáveis

### Shell Scripts (mínimo)
- Apenas para provisioners que executam via `pct exec`
- `download_template.sh`, `install_docker.sh`

### Regra Geral
Sempre que existir um resource/data source no Terraform provider, usar Terraform. Scripts Python apenas para:
1. Bootstrap inicial (operações únicas sem resource)
2. Orquestração de fases
3. Verificação de dependências

## Credenciais

| Tipo | Método |
|------|--------|
| Senhas | `random_password` em `random.tf` |
| Chaves | `random_bytes` em `random.tf` |
| IPs | `data.http` em `data_container_ip.tf` |
| Tokens | Bootstrap → `.auto.tfvars` |

**Nunca hardcode senhas ou tokens!**

## Fluxo de Deploy

1. `make apply` → `deploy.py`
2. Phase 1: `module.docker_lxc` + `data.http.container_interfaces`
3. Phase 2: `module.infisical`
4. Phase 3: `null_resource.bootstrap_infisical` → `bootstrap_infisical.py`
5. Phase 4: `infisical_identity.*` resources

## Arquivos Importantes

| Arquivo | Propósito |
|---------|-----------|
| `terraform.tfvars` | Configurações do usuário (não versionado) |
| `*.auto.tfvars` | Gerados pelo bootstrap (não versionado) |
| `random.tf` | Geração de todas as credenciais |
| `data_container_ip.tf` | IP dinâmico via API Proxmox |

## Testes

Após alterações:
```bash
terraform validate
terraform plan
```

Após deploy:
```bash
terraform output docker_container_ip
curl http://<ip>:8080/api/status
```
