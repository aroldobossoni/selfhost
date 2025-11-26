# Comparação de Soluções de Secrets Management

Este documento compara as principais soluções de gerenciamento de secrets para o projeto selfhost.

## Tabela Comparativa Geral

| Critério | HashiCorp Vault | Infisical | Doppler | SOPS + Age |
|----------|----------------|-----------|---------|------------|
| **Tipo** | Self-hosted | Self-hosted | SaaS | File-based |
| **Complexidade** | Alta | Média | Baixa | Baixa |
| **Custo** | Gratuito (OSS) | Gratuito (OSS) | Freemium | Gratuito |
| **Self-hosted** | ✅ Sim | ✅ Sim | ❌ Não | ✅ Sim (arquivos) |
| **API REST** | ✅ Sim | ✅ Sim | ✅ Sim | ❌ Não |
| **Integração Terraform** | ✅ Nativa | ✅ Via provider | ✅ Via provider | ⚠️ Manual |
| **Rotação automática** | ✅ Sim | ✅ Sim | ✅ Sim | ❌ Não |
| **Auditoria** | ✅ Completa | ✅ Sim | ✅ Sim | ⚠️ Via Git |
| **UI Web** | ✅ Sim | ✅ Sim | ✅ Sim | ❌ Não |
| **Multi-cloud** | ✅ Sim | ✅ Sim | ✅ Sim | ✅ Sim |
| **GitOps friendly** | ⚠️ Média | ✅ Sim | ✅ Sim | ✅✅ Sim |

## HashiCorp Vault

### Vantagens

- **Enterprise-grade**: Solução robusta e madura, amplamente adotada
- **Funcionalidades avançadas**: Rotação automática, dynamic secrets, encryption as a service
- **Multi-backend**: Suporta múltiplos backends de storage (Consul, etcd, S3, etc.)
- **Provider Terraform nativo**: Integração direta via `terraform-provider-vault`
- **Segurança**: Audit logging completo, políticas granulares de acesso
- **Comunidade**: Grande comunidade e ecossistema
- **Documentação**: Documentação extensa e exemplos

### Desvantagens

- **Complexidade**: Configuração inicial complexa, curva de aprendizado alta
- **Recursos**: Requer recursos significativos (CPU, memória)
- **Operação**: Necessita manutenção e monitoramento contínuos
- **Overhead**: Pode ser excessivo para projetos pequenos
- **Setup inicial**: Requer configuração de storage backend, políticas, etc.

### Integração com Terraform

```hcl
provider "vault" {
  address = "http://vault:8200"
  token   = var.vault_token
}

data "vault_generic_secret" "proxmox" {
  path = "secret/proxmox"
}

variable "pm_api_token_id" {
  value = data.vault_generic_secret.proxmox.data["token_id"]
}
```

### Casos de Uso Ideais

- Projetos enterprise com múltiplas equipes
- Necessidade de rotação automática de secrets
- Requisitos de auditoria rigorosos
- Ambientes multi-cloud complexos

---

## Infisical

### Vantagens

- **Open-source**: Código aberto, comunidade ativa
- **Simplicidade**: Mais simples que Vault, mas com recursos essenciais
- **UI moderna**: Interface web intuitiva e moderna
- **GitOps**: Integração nativa com GitOps workflows
- **Self-hosted**: Controle total sobre dados e infraestrutura
- **Terraform**: Provider disponível para integração
- **Documentação**: Boa documentação e exemplos práticos

### Desvantagens

- **Menos maduro**: Menos tempo no mercado que Vault
- **Funcionalidades**: Algumas funcionalidades avançadas podem faltar
- **Comunidade**: Menor que Vault, mas crescendo
- **Recursos**: Ainda requer recursos para operação
- **Ecosistema**: Menos integrações prontas disponíveis

### Integração com Terraform

```hcl
provider "infisical" {
  host_url = "https://infisical.example.com"
  token    = var.infisical_token
}

data "infisical_secrets" "proxmox" {
  project_id = "project-id"
  path       = "/proxmox"
}

variable "pm_api_token_id" {
  value = data.infisical_secrets.proxmox.secrets["token_id"]
}
```

### Casos de Uso Ideais

- Projetos que precisam de self-hosted mas com menos complexidade
- Equipes que preferem UI moderna
- Workflows GitOps-first
- Projetos de médio porte

---

## Doppler

### Vantagens

- **Simplicidade**: Setup extremamente simples, zero configuração
- **UI excelente**: Interface web muito intuitiva
- **CLI robusto**: Ferramenta CLI poderosa e fácil de usar
- **Integração**: Integrações prontas com muitas ferramentas
- **Suporte**: Bom suporte e documentação
- **Terraform**: Provider disponível
- **Gerenciado**: Sem necessidade de operar infraestrutura

### Desvantagens

- **SaaS**: Dados armazenados externamente (não self-hosted)
- **Custo**: Plano gratuito limitado, custos para uso intensivo
- **Dependência**: Dependência de serviço externo
- **Compliance**: Pode não atender requisitos de compliance rigorosos
- **Offline**: Requer conexão com internet para funcionar

### Integração com Terraform

```hcl
provider "doppler" {
  doppler_token = var.doppler_token
}

data "doppler_secrets" "proxmox" {
  project = "selfhost"
  config  = "production"
}

variable "pm_api_token_id" {
  value = data.doppler_secrets.proxmox.map["PM_API_TOKEN_ID"]
}
```

### Casos de Uso Ideais

- Projetos que não requerem self-hosted
- Equipes pequenas que precisam de solução rápida
- Prototipagem e desenvolvimento rápido
- Projetos com orçamento para SaaS

---

## SOPS + Age

### Vantagens

- **GitOps nativo**: Arquivos encriptados podem ser versionados no Git
- **Zero infraestrutura**: Não requer servidor ou serviço adicional
- **Simplicidade**: Conceito simples, fácil de entender
- **Portabilidade**: Arquivos podem ser movidos entre ambientes facilmente
- **Offline**: Funciona completamente offline
- **Custo zero**: Sem custos de infraestrutura ou licenças
- **Transparência**: Secrets visíveis no Git (encriptados), fácil auditoria

### Desvantagens

- **Sem API**: Não há API REST para acesso dinâmico
- **Rotação manual**: Rotação de secrets requer processo manual
- **Sem UI**: Sem interface web, apenas CLI
- **Gestão de chaves**: Necessita gerenciar chaves de encriptação manualmente
- **Terraform**: Integração com Terraform requer configuração adicional
- **Escalabilidade**: Pode ser limitado para muitos secrets ou equipes grandes

### Integração com Terraform

```hcl
# Requer sops provider ou uso de external data source
data "external" "sops" {
  program = ["sops", "-d", "--output-type", "json", "secrets.enc.yaml"]
}

variable "pm_api_token_id" {
  value = jsondecode(data.external.sops.result)["pm_api_token_id"]
}
```

### Casos de Uso Ideais

- Projetos GitOps-first
- Equipes pequenas
- Ambientes onde self-hosted é crítico mas sem recursos para servidor
- Projetos que já usam Git para versionamento
- Orçamento zero para infraestrutura

---

## Recomendação para Projeto Selfhost

### Análise do Projeto

O projeto selfhost tem as seguintes características:
- **Self-hosted**: Prioriza controle total sobre infraestrutura
- **Proxmox VE**: Infraestrutura local, não cloud
- **Terraform**: IaC como base do projeto
- **Escopo**: Projeto pessoal/small team
- **Recursos**: Container LXC com recursos limitados

### Recomendação: **SOPS + Age**

**Justificativa:**

1. **Alinhamento com filosofia self-hosted**: Não requer servidor adicional
2. **GitOps-friendly**: Secrets versionados no Git (encriptados)
3. **Simplicidade**: Menos complexidade operacional
4. **Recursos**: Não consome recursos adicionais do Proxmox
5. **Custo zero**: Sem custos de infraestrutura ou SaaS
6. **Terraform**: Integração possível via sops provider

### Alternativa: **Infisical** (se precisar de API/UI)

Se o projeto evoluir e precisar de:
- API REST para acesso dinâmico
- Interface web para gestão
- Rotação automática de secrets
- Múltiplas equipes

Nesse caso, **Infisical** seria a melhor opção self-hosted, mais simples que Vault mas com recursos essenciais.

### Não Recomendado

- **HashiCorp Vault**: Overkill para projeto atual, muito complexo
- **Doppler**: Não é self-hosted, contradiz filosofia do projeto

---

## Próximos Passos

1. Implementar SOPS + Age no projeto
2. Criar estrutura de secrets encriptados
3. Configurar integração com Terraform
4. Documentar processo de gestão de secrets

