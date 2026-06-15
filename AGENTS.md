# AGENTS.md

Instruções para agentes de IA e Codex ao operar neste repositório.

## Papel do repositório

Este repositório é a fonte de contexto arquitetural do case **Logística Envios**. Ele não é o código-fonte dos microservices. Ele define:

- mapa dos microservices;
- responsabilidades;
- contratos REST;
- eventos Kafka;
- diagramas C4;
- decisões arquiteturais;
- padrões de implementação;
- comandos de validação local.

## Regras para o Codex

1. Antes de gerar código, leia:
   - `README.md`
   - `docs/contracts/services-map.md`
   - `docs/contracts/kafka-events.md`
   - `docs/adr/*.md`

2. Não alterar contratos sem atualizar:
   - documentação do serviço afetado;
   - evento Kafka relacionado, se existir;
   - ADR, se houver mudança arquitetural relevante.

3. Não criar microservice novo sem justificar:
   - responsabilidade;
   - boundaries;
   - dados que domina;
   - APIs expostas;
   - eventos publicados/consumidos.

4. Preferir implementação em:
   - .NET 8;
   - C#;
   - arquitetura limpa/hexagonal;
   - API REST;
   - Kafka para integração assíncrona;
   - Docker para execução local.

5. Padrões obrigatórios:
   - idempotência em comandos críticos;
   - correlationId em APIs e eventos;
   - observabilidade com logs estruturados, métricas e traces;
   - fallback para dependências externas;
   - timeout explícito;
   - retry com backoff apenas em chamadas idempotentes;
   - circuit breaker em integrações instáveis.

## Comandos de validação esperados

```bash
docker compose config
docker compose up -d
```

Quando houver código .NET em repositórios de microservice:

```bash
dotnet restore
dotnet build
dotnet test
dotnet format --verify-no-changes
```

## Convenções

### Nome de tópicos Kafka

Formato:

```text
<domain>.<entity>.<event>
```
