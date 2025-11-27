# Relatório de Hardcodes no Projeto

## ✅ Removidos

- `docker_host_ip` - Agora obtido dinamicamente ou via configuração
- `infisical_port` fallbacks - Agora obrigatório em terraform.tfvars
- `localhost:8080` fallbacks - Removidos de todos os arquivos

## 📋 Configurações Centralizadas

Todas as configurações estão em `terraform.tfvars`:

| Variável | Descrição | Obrigatória |
|----------|-----------|-------------|
| `pm_api_url` | URL da API Proxmox | Sim |
| `pm_api_token_id` | Token ID do Proxmox | Sim |
| `pm_api_token_secret` | Secret do token | Sim |
| `pm_host` | IP/hostname do Proxmox | Sim |
| `docker_host_ip` | IP do container Docker | Não (dinâmico) |
| `infisical_port` | Porta HTTP do Infisical | Sim |
| `infisical_admin_email` | Email do admin | Sim |
| `infisical_org_name` | Nome da organização | Sim |

## 📝 Observações

1. **Documentação**: IPs em arquivos de documentação são exemplos ilustrativos
2. **Usuário root**: Necessário para SSH/Proxmox (não configurável)
3. **Sem fallbacks**: Todas as configurações devem ser explícitas
