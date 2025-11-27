# Relatório de Hardcodes no Projeto

## ✅ Removidos

- `docker_host_ip` - Agora obtido dinamicamente via SSH quando não fornecido

## 📋 Hardcodes Restantes (Documentação/Exemplos)

### IPs em Documentação (Aceitáveis - são exemplos)
- `README.md`: 192.168.3.2 (exemplo Proxmox)
- `AGENTS.md`: 192.168.3.2 (documentação)
- `terraform.tfvars.example`: 192.168.3.2 (exemplo)
- `docs/INFISICAL_DEPLOYMENT.md`: 192.168.3.115 (exemplo)
- `docs/ARCHITECTURE.md`: 192.168.3.2 (diagrama)
- `modules/infisical/README.md`: 192.168.3.115 (exemplo)

### Portas com Defaults (Aceitáveis - valores padrão)
- `variables.tf`: `infisical_port` default = 8080
- `modules/infisical/variables.tf`: `infisical_port` default = 8080
- `scripts/deploy.py`: fallback "8080" quando não configurado
- `scripts/infisical_client.py`: default port = 8080
- `scripts/configure_infisical.py`: default port = 8080
- `infisical_provider.tf`: fallback "localhost:8080" (quando Infisical desabilitado)
- `modules/infisical/main.tf`: fallback "localhost:8080"

### Usuário root (Necessário para SSH/Proxmox)
- `providers.tf`: "ssh://root@${local.docker_host_ip}" (necessário para Docker provider)
- `scripts/install_docker.sh`: "root@${PROXMOX_HOST}" (necessário para Proxmox)
- `scripts/download_template.sh`: Provavelmente usa root@
- `locals.tf`: "root@${PM_HOST}" (necessário para SSH)
- `scripts/deploy.py`: "root@{pm_host}" (necessário para SSH)

### Exemplos de Token
- `terraform.tfvars.example`: "root@pam!terraform" (exemplo de formato)

### Fallbacks Localhost (Aceitáveis - quando serviço desabilitado)
- `infisical_provider.tf`: "http://localhost:8080" (quando enable_infisical = false)
- `modules/infisical/main.tf`: "http://localhost:8080" (quando server_url não fornecido)

## 📝 Observações

1. **IPs em documentação**: São exemplos e não afetam o funcionamento
2. **Portas com defaults**: Valores padrão que podem ser sobrescritos via variáveis
3. **Usuário root**: Necessário para operações SSH/Proxmox, não pode ser mudado facilmente
4. **Fallbacks localhost**: Usados apenas quando serviços estão desabilitados

## 🎯 Conclusão

O único hardcode problemático (`docker_host_ip`) foi removido. Os demais são:
- Exemplos em documentação (não afetam execução)
- Valores padrão configuráveis via variáveis
- Necessários para funcionamento do sistema (root@, localhost fallbacks)
