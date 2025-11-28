# Relatório de Hardcodes no Projeto

## ✅ Credenciais Auto-Geradas

| Credential | Método | Rotação |
|------------|--------|---------|
| `docker_lxc_password` | `random_password` | A cada `terraform apply` (se destruído) |
| `infisical_admin_password` | `random_password` | A cada `terraform apply` (se destruído) |
| `postgres_password` | `random_password` | A cada `terraform apply` (se destruído) |
| `encryption_key` | `random_bytes` | A cada `terraform apply` (se destruído) |
| `jwt_signing_key` | `random_password` | A cada `terraform apply` (se destruído) |
| `infisical_client_id` | Infisical API | Bootstrap automático |
| `infisical_client_secret` | Infisical API | Bootstrap automático |

## ✅ Configurações Dinâmicas

| Variável | Método | Descrição |
|----------|--------|-----------|
| `docker_host_ip` | Proxmox API | Obtido via `/nodes/{node}/lxc/{vmid}/interfaces` |
| `container_vmid` | Terraform | Retornado pelo provider Proxmox |

## ⚠️ Configurações Manuais (terraform.tfvars)

| Variável | Descrição | Sensível |
|----------|-----------|----------|
| `pm_api_url` | URL da API Proxmox | Não |
| `pm_api_token_id` | Token ID do Proxmox | Sim |
| `pm_api_token_secret` | Secret do token | Sim |
| `pm_host` | IP/hostname do Proxmox | Não |
| `pm_node` | Nome do node Proxmox | Não |
| `proxmox_ssh_user` | Usuário SSH (default: root) | Não |
| `docker_ssh_user` | Usuário SSH do LXC (default: root) | Não |
| `infisical_port` | Porta HTTP do Infisical | Não |
| `infisical_admin_email` | Email do admin | Não |
| `infisical_org_name` | Nome da organização | Não |
| `infisical_project_name` | Nome do projeto | Não |

## 📝 Observações

1. **Proxmox API Token**: Ainda é manual, mas está no roadmap para substituir por autenticação SSH
2. **Documentação**: IPs em arquivos de documentação são exemplos ilustrativos
3. **Sem fallbacks**: Todas as configurações obrigatórias devem ser explícitas
4. **Arquivos .auto.tfvars**: Gerados automaticamente pelo bootstrap, ignorados pelo git
