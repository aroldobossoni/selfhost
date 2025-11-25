# AGENTS.md - Documentação para Agentes de IA

Este documento fornece informações essenciais para agentes de IA trabalharem neste projeto de forma eficiente e com baixo consumo de tokens.

## Contexto do Projeto

Projeto de infraestrutura como código usando Terraform para gerenciar serviços self-hosted no Proxmox VE. O projeto prioriza modularização e fragmentação para facilitar o trabalho de agentes de IA.

## Estrutura Modular

O projeto está organizado em módulos independentes, cada um em seu próprio diretório:

- `modules/docker_lxc/`: Módulo para criação de LXC com Docker
- Futuros módulos seguirão o mesmo padrão

Cada módulo contém:
- `variables.tf`: Definição de variáveis de entrada
- `main.tf`: Recursos principais do módulo
- `outputs.tf`: Outputs do módulo

## Convenções de Código

- **Nomes**: Variáveis, recursos e outputs em inglês
- **Comentários**: Em inglês, objetivos e decisões importantes
- **Documentação**: Concisas, focadas em objetivos
- **Modularização**: Priorizar módulos pequenos e focados

## Informações Técnicas Importantes

### Terraform
- Versão mínima: 1.14.0
- Provider Proxmox: `telmate/proxmox`
- Backend: Local (pode ser configurado para remoto)

### Proxmox VE
- Servidor: 192.168.3.2
- Acesso SSH: root@192.168.3.2 (chave SSH configurada)
- API: Porta 8006 (HTTPS)

### Docker LXC Module
- Baseado no script helper: https://github.com/tteck/Proxmox/raw/main/ct/docker.sh
- Container LXC privilegiado com nesting habilitado
- Instala Docker, Docker Compose e Portainer (opcional)

## Diretrizes para Agentes

1. **Fragmentação**: Trabalhar em um módulo por vez quando possível
2. **Leitura Seletiva**: Ler apenas arquivos relevantes ao contexto atual
3. **Evitar Duplicação**: Verificar código existente antes de criar novo
4. **Manter Modularidade**: Não acoplar módulos desnecessariamente
5. **Documentação Concisa**: Comentários objetivos, sem verbosidade

## Fluxo de Trabalho Recomendado

1. Identificar o módulo/arquivo relevante
2. Ler apenas os arquivos necessários do módulo
3. Fazer alterações focadas
4. Atualizar documentação se necessário
5. Manter outputs e variáveis bem definidos

## Variáveis Sensíveis

Variáveis sensíveis (tokens, senhas) devem ser:
- Definidas em `variables.tf`
- Valores em `terraform.tfvars` (não versionado)
- Exemplo em `terraform.tfvars.example`

## Padrões de Nomenclatura

- Recursos: `proxmox_lxc`, `proxmox_vm_qemu`
- Variáveis: `snake_case`
- Módulos: `snake_case` (diretório e nome)
- Outputs: `snake_case`

