# Selfhost - Stack Proxmox VE com Terraform

Infraestrutura como código para gerenciar serviços self-hosted no Proxmox VE utilizando Terraform.

## Objetivo

Automatizar a implantação e gerenciamento de uma stack completa de serviços self-hosted no Proxmox VE, incluindo:

- Argo CD
- Key Vault
- OPNsense
- Authentik
- Grafana
- Docker

Priorizando o uso de containers LXC para economizar recursos.

## Pré-requisitos

- Terraform >= 1.14.0
- Acesso SSH ao servidor Proxmox VE (root@192.168.3.2)
- Token de API do Proxmox VE configurado
- Chave SSH configurada para acesso ao Proxmox

## Estrutura do Projeto

```
.
├── modules/
│   └── docker_lxc/          # Módulo para criação de LXC com Docker
├── main.tf                   # Configuração principal
├── variables.tf              # Variáveis do projeto
├── outputs.tf                # Outputs do projeto
├── providers.tf              # Configuração dos providers
├── versions.tf               # Versões do Terraform e providers
└── terraform.tfvars.example  # Exemplo de variáveis
```

## Uso Rápido

1. Copie o arquivo de exemplo de variáveis:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```

2. Edite `terraform.tfvars` com suas credenciais do Proxmox:
   - `pm_api_url`: URL da API do Proxmox (ex: https://192.168.3.2:8006/api2/json)
   - `pm_api_token_id`: ID do token de API
   - `pm_api_token_secret`: Secret do token de API

3. Inicialize o Terraform:
   ```bash
   terraform init
   ```

4. Revise o plano de execução:
   ```bash
   terraform plan
   ```

5. Aplique a configuração:
   ```bash
   terraform apply
   ```

## Criação do Token API no Proxmox

1. Acesse a interface web do Proxmox VE
2. Navegue até **Datacenter** > **Permissions** > **API Tokens**
3. Clique em **Add** e crie um token para o usuário desejado
4. Configure as permissões necessárias (geralmente Administrator role)
5. Copie o `Token ID` e `Secret` para o arquivo `terraform.tfvars`

## Módulos

### docker_lxc

Módulo para criação de um container LXC com Docker instalado, baseado no script helper da comunidade Proxmox VE.

**Variáveis principais:**
- `hostname`: Nome do host do container
- `cores`: Número de cores CPU
- `memory`: Memória em MB
- `storage`: Storage para o rootfs
- `ostemplate`: Template do sistema operacional

## Próximos Passos

- [ ] Integração com Argo CD
- [ ] Integração com Key Vault
- [ ] Integração com OPNsense
- [ ] Integração com Authentik
- [ ] Integração com Grafana

## Referências

- [Proxmox VE Helper Scripts](https://community-scripts.github.io/ProxmoxVE/)
- [Terraform Provider Proxmox](https://github.com/Telmate/terraform-provider-proxmox)

