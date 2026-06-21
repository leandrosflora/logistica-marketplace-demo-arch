# AGENTS.md

Instruções para agentes de IA e Codex ao operar neste repositório.

## Papel do repositório

Este repositório é a fonte de contexto arquitetural do case **Logística Envios**. Ele não é o código-fonte dos microservices. Ele define:

- mapa dos microservices;
- responsabilidades e specs individuais por serviço;
- contratos REST;
- eventos Kafka e schema governance;
- diagramas C4;
- decisões arquiteturais (ADRs);
- glossário de domínio;
- documentação de segurança;
- padrões de implementação;
- pipeline CI/CD esperado;
- comandos de validação local.

## Regras para o Codex

1. Antes de gerar código, leia:
   - `README.md`
   - `docs/contracts/services-map.md`
   - `docs/contracts/kafka-events.md`
   - `docs/adr/*.md`
   - `docs/glossary/domain-glossary.md` — termos do domínio de logística e envios
   - `docs/security/security-architecture.md` — autenticação, autorização e propagação de identidade
   - `docs/services/<nome>-service.md` — spec do serviço sendo implementado (boundaries, dados, APIs, SLOs, regras de negócio)

2. Não alterar contratos sem atualizar:
   - documentação do serviço afetado;
   - evento Kafka relacionado, se existir;
   - ADR, se houver mudança arquitetural relevante;
   - `docs/contracts/kafka-schema-governance.md` ao evoluir schemas Kafka (leia antes de implementar consumers ou producers Kafka).

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
   - idempotência em comandos críticos (Inbox/Outbox Pattern — ver [ADR-0005](docs/adr/0005-idempotency-strategy.md));
   - correlationId em APIs e eventos (ver [docs/security/security-architecture.md](docs/security/security-architecture.md));
   - observabilidade com logs estruturados, métricas e traces via OpenTelemetry (ver [ADR-0006](docs/adr/0006-observability-stack.md));
   - fallback para dependências externas;
   - timeout explícito;
   - retry com backoff apenas em chamadas idempotentes;
   - circuit breaker em integrações instáveis;
   - arquitetura hexagonal/clean obrigatória (ver [ADR-0003](docs/adr/0003-hexagonal-clean-architecture.md)).

6. Ao criar novo microservice, criar spec correspondente em `docs/services/<nome>-service.md` seguindo o template dos serviços existentes.

7. Ao evoluir schemas Kafka, seguir processo em `docs/contracts/kafka-schema-governance.md` (leia antes de implementar qualquer producer ou consumer Kafka).

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
