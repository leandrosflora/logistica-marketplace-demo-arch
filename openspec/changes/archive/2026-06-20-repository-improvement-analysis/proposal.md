## Why

O repositório `meli-envios-architecture` é a fonte de contexto arquitetural para todos os agentes e desenvolvedores do case Meli Envios, mas possui lacunas significativas: ADRs ausentes para decisões já tomadas, ausência de stack de observabilidade local, sem glossário de domínio, sem documentação de segurança, e diagramas C4 nível 3 incompletos para vários domínios. Essas lacunas reduzem a qualidade do contexto fornecido ao Codex e aumentam o risco de implementações inconsistentes.

## What Changes

- Criar ADRs faltantes para decisões arquiteturais já em uso mas não documentadas (padrão Saga, stack de observabilidade, estratégia de versionamento de schemas Kafka, arquitetura hexagonal, estratégia de idempotência).
- Adicionar glossário de domínio (ubiquitous language) com todos os termos do domínio de logística/envios.
- Adicionar documentação de arquitetura de segurança (autenticação, autorização, propagação de identidade entre serviços).
- Adicionar especificações individuais de microservices com boundaries, dados dominados, SLOs e dependências.
- Adicionar stack de observabilidade ao `docker-compose.yml` (Prometheus, Grafana, Jaeger/OTEL Collector).
- Adicionar scripts SQL de inicialização do Postgres para habilitar E2E local completo.
- Adicionar documentação de schema governance Kafka (estratégia de versionamento, compatibilidade, processo de evolução).
- Completar diagramas C4 nível 3 para os domínios sem cobertura (Checkout, ShippingPromise, Pricing, Carrier, Inventory, Fulfillment, Routing).
- Atualizar README para refletir estrutura real (incluir `docs/reviews/` e `docs/runbooks/`).
- Adicionar documentação de pipeline CI/CD esperado para microservices .NET 8.

## Capabilities

### New Capabilities

- `missing-adrs`: Conjunto de ADRs faltantes cobrindo decisões já adotadas mas não documentadas — padrão Saga Orchestrator no OrderService, estratégia hexagonal/clean architecture, versionamento de schemas Kafka, estratégia de idempotência e circuit breaker.
- `domain-glossary`: Glossário de ubiquitous language do domínio Meli Envios com definições de termos como shipment, promise, fulfillment center, carrier, route, SLA, SLO, SKU, checkout, label, tracking code, etc.
- `security-architecture`: Documentação de arquitetura de segurança — autenticação (JWT/OAuth2), propagação de `x-correlation-id`/`x-client-id`, autorização por serviço, e estratégia de segredo (Vault/env).
- `service-specs`: Especificações individuais de cada microservice com boundaries, dados dominados, contratos publicados/consumidos, SLOs, dependências e regras de negócio principais.
- `observability-stack`: Documentação e configuração da stack de observabilidade local — Prometheus, Grafana, Jaeger/OTEL Collector — adicionados ao `docker-compose.yml` com runbook de uso.
- `schema-governance`: Documentação de governança de schemas Kafka — estratégia de versionamento (v1, v2), backward/forward compatibility, processo de evolução de contrato, responsabilidades de owner.
- `missing-c4-diagrams`: Diagramas C4 nível 3 para os domínios sem cobertura atual (Checkout, ShippingPromise, Pricing, Carrier, Inventory, Fulfillment, Routing).
- `cicd-pipeline-docs`: Documentação do pipeline CI/CD esperado para microservices .NET 8 — etapas de build, test, format, análise estática, container build e deploy.

### Modified Capabilities

- `kafka-contracts`: Adicionar campo `sellerId` faltante no payload de `shipment.created`, e documentar formalmente os eventos canônicos ausentes (`order.confirmed`, `order.cancelled`, `payment.approved`, `payment.rejected`, `shipment.cancelled`) mencionados nos ADRs mas não especificados.

## Impact

- `docs/adr/` — novos arquivos ADR (0002 a 0006).
- `docs/contracts/kafka-events.md` — adição de eventos canônicos ausentes e campo `sellerId` em `shipment.created`.
- `docs/c4/` — novos arquivos `.puml` e `.svg` para domínios sem nível 3.
- `docs/` — novos diretórios `docs/glossary/`, `docs/security/`, `docs/services/`, `docs/cicd/`.
- `docker-compose.yml` — adição de serviços Prometheus, Grafana, Jaeger e scripts de init do Postgres.
- `docs/runbooks/` — atualização do runbook E2E e novo runbook de observabilidade.
- `README.md` — atualização da seção Estrutura para refletir os novos diretórios.
- `AGENTS.md` — atualização das regras para incluir referências ao glossário e specs de serviço.
