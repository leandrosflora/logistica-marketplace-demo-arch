## ADDED Requirements

### Requirement: ADR para padrão Saga Orchestrator no OrderService
O repositório SHALL conter um ADR (`docs/adr/0002-saga-orchestrator-pattern.md`) documentando a decisão de usar Saga Orchestrator centralizado no `OrderService` para coordenar reservas de estoque, autorização de pagamento e criação de shipment.

#### Scenario: ADR de Saga Orchestrator criado
- **WHEN** o arquivo `docs/adr/0002-saga-orchestrator-pattern.md` é lido
- **THEN** ele MUST conter seções Status, Contexto, Decisão, Consequências positivas, Consequências negativas e Regras
- **THEN** ele MUST documentar que o `OrderService` é o orquestrador usando tópicos internos `inventory.commands`, `fulfillment.commands`, `payment.commands` e `shipment.commands`
- **THEN** ele MUST referenciar a `ADR-0001` de tópicos internos de saga

### Requirement: ADR para arquitetura hexagonal e clean architecture
O repositório SHALL conter um ADR (`docs/adr/0003-hexagonal-clean-architecture.md`) documentando a decisão de adotar arquitetura hexagonal/clean em todos os microservices, com separação explícita de Domain, Application, Infrastructure e API.

#### Scenario: ADR de arquitetura hexagonal criado
- **WHEN** o arquivo `docs/adr/0003-hexagonal-clean-architecture.md` é lido
- **THEN** ele MUST descrever as camadas obrigatórias (Domain, Application, Infrastructure, API)
- **THEN** ele MUST especificar que dependências DEVEM apontar para o interior (Domain não conhece Infrastructure)
- **THEN** ele MUST listar as regras de projeto (.NET) correspondentes a cada camada

### Requirement: ADR para estratégia de versionamento de schemas Kafka
O repositório SHALL conter um ADR (`docs/adr/0004-kafka-schema-versioning.md`) documentando a estratégia de versionamento de schemas dos eventos Kafka canônicos.

#### Scenario: ADR de schema versioning criado
- **WHEN** o arquivo `docs/adr/0004-kafka-schema-versioning.md` é lido
- **THEN** ele MUST definir que mudanças backward-compatible (adição de campo opcional) resultam em incremento de minor version (`schemaVersion` 1.0 → 1.1)
- **THEN** ele MUST definir que mudanças breaking (remoção de campo, renaming, mudança de tipo) exigem nova versão major e novo ADR
- **THEN** ele MUST especificar que todos os consumers DEVEM ignorar campos desconhecidos (tolerant reader pattern)

### Requirement: ADR para estratégia de idempotência
O repositório SHALL conter um ADR (`docs/adr/0005-idempotency-strategy.md`) documentando a estratégia de idempotência em APIs e consumers Kafka.

#### Scenario: ADR de idempotência criado
- **WHEN** o arquivo `docs/adr/0005-idempotency-strategy.md` é lido
- **THEN** ele MUST documentar que APIs de comando DEVEM aceitar `x-idempotency-key` no header
- **THEN** ele MUST documentar que consumers Kafka DEVEM implementar Inbox Pattern para garantir exactly-once processing
- **THEN** ele MUST documentar que producers Kafka DEVEM implementar Outbox Pattern para garantir at-least-once delivery com idempotência no consumer

### Requirement: ADR para stack de observabilidade
O repositório SHALL conter um ADR (`docs/adr/0006-observability-stack.md`) documentando a decisão sobre a stack de observabilidade adotada (métricas, traces, logs).

#### Scenario: ADR de observabilidade criado
- **WHEN** o arquivo `docs/adr/0006-observability-stack.md` é lido
- **THEN** ele MUST documentar a escolha de OpenTelemetry SDK como abstração de instrumentação
- **THEN** ele MUST documentar Prometheus+Grafana para métricas e Jaeger para traces
- **THEN** ele MUST especificar que logs DEVEM ser estruturados em JSON com campos obrigatórios: `timestamp`, `level`, `service`, `correlationId`, `traceId`, `message`
