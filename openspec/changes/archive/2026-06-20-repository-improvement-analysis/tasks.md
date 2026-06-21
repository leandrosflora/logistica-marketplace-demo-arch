## 1. ADRs Faltantes

- [x] 1.1 Criar `docs/adr/0002-saga-orchestrator-pattern.md` documentando o padrão Saga Orchestrator centralizado no OrderService com tópicos internos de saga
- [x] 1.2 Criar `docs/adr/0003-hexagonal-clean-architecture.md` documentando a adoção obrigatória de arquitetura hexagonal/clean em todos os microservices
- [x] 1.3 Criar `docs/adr/0004-kafka-schema-versioning.md` documentando a estratégia de versionamento de schemas Kafka (backward-compatible vs breaking, minor vs major)
- [x] 1.4 Criar `docs/adr/0005-idempotency-strategy.md` documentando Inbox Pattern (consumers) e Outbox Pattern (producers) como estratégia padrão de idempotência
- [x] 1.5 Criar `docs/adr/0006-observability-stack.md` documentando a escolha de OpenTelemetry + Prometheus + Grafana + Jaeger como stack de observabilidade

## 2. Glossário de Domínio

- [x] 2.1 Criar diretório `docs/glossary/`
- [x] 2.2 Criar `docs/glossary/domain-glossary.md` com definições dos termos: Checkout, Shipping Promise, SKU, Seller, Buyer, Fulfillment Center, Carrier, Route, Service Level, SLA, SLO, Shipment, Label, Tracking Code, Tracking Event, Delivery Exception, Order, Package, Cutoff, Hub, Malha Logística, Same Day, Next Day, Standard, Subsídio de Frete, Corridor
- [x] 2.3 Atualizar `AGENTS.md` para incluir referência a `docs/glossary/domain-glossary.md` na lista de leitura obrigatória

## 3. Documentação de Segurança

- [x] 3.1 Criar diretório `docs/security/`
- [x] 3.2 Criar `docs/security/security-architecture.md` com seções: mecanismo de autenticação (JWT/OAuth2), propagação de headers (`x-correlation-id`, `x-client-id`, `x-idempotency-key`), fluxo de identidade de APIs para Kafka, gestão de segredos
- [x] 3.3 Referenciar `docs/security/security-architecture.md` no `AGENTS.md` e no `README.md`

## 4. Schema Governance Kafka

- [x] 4.1 Criar `docs/contracts/kafka-schema-governance.md` com: regras de versionamento (backward-compatible vs breaking), processo de evolução de contrato (PR → ADR se breaking → schemaVersion → notificação → período de coexistência), Tolerant Reader pattern obrigatório, tabela de ownership de tópicos
- [x] 4.2 Atualizar `AGENTS.md` para referenciar `docs/contracts/kafka-schema-governance.md` como leitura obrigatória ao implementar consumers Kafka

## 5. Atualização de Contratos Kafka

- [x] 5.1 Adicionar campo `sellerId` ao payload canônico de `shipment.created` em `docs/contracts/kafka-events.md`, atualizar `schemaVersion` para `1.1`
- [x] 5.2 Documentar evento `order.confirmed` em `docs/contracts/kafka-events.md` com producer, consumers e payload canônico
- [x] 5.3 Documentar evento `order.cancelled` em `docs/contracts/kafka-events.md` com producer, consumers e payload canônico
- [x] 5.4 Documentar evento `payment.approved` em `docs/contracts/kafka-events.md` com producer, consumers e payload canônico
- [x] 5.5 Documentar evento `payment.rejected` em `docs/contracts/kafka-events.md` com producer, consumers e payload canônico
- [x] 5.6 Documentar evento `shipment.cancelled` em `docs/contracts/kafka-events.md` com producer, consumers e payload canônico
- [x] 5.7 Atualizar a matriz final de contratos canônicos em `docs/contracts/kafka-events.md` para incluir os 5 novos eventos

## 6. Specs Individuais de Microservice

- [x] 6.1 Criar diretório `docs/services/`
- [x] 6.2 Criar `docs/services/checkout-service.md` com: responsabilidade, dados dominados, APIs, eventos Kafka, dependências síncronas, SLOs, regras de negócio
- [x] 6.3 Criar `docs/services/shipping-promise-service.md`
- [x] 6.4 Criar `docs/services/product-catalog-service.md`
- [x] 6.5 Criar `docs/services/product-search-service.md`
- [x] 6.6 Criar `docs/services/inventory-service.md`
- [x] 6.7 Criar `docs/services/fulfillment-center-service.md`
- [x] 6.8 Criar `docs/services/routing-service.md`
- [x] 6.9 Criar `docs/services/carrier-service.md`
- [x] 6.10 Criar `docs/services/shipping-pricing-service.md`
- [x] 6.11 Criar `docs/services/order-service.md`
- [x] 6.12 Criar `docs/services/shipment-service.md`
- [x] 6.13 Criar `docs/services/tracking-service.md`
- [x] 6.14 Criar `docs/services/notification-service.md`
- [x] 6.15 Criar `docs/services/audit-service.md`
- [x] 6.16 Atualizar `README.md` para listar `docs/services/` na seção Estrutura e adicionar links para specs na tabela de microservices
- [x] 6.17 Atualizar `AGENTS.md` para instruir leitura de `docs/services/<nome>-service.md` antes de gerar código para o serviço correspondente

## 7. Stack de Observabilidade

- [x] 7.1 Criar diretório `monitoring/` com arquivo `monitoring/prometheus.yml` configurado com scrape interval de 15s e jobs para os microservices
- [x] 7.2 Criar diretório `monitoring/grafana/provisioning/` com estrutura de provisioning de datasources e dashboards
- [x] 7.3 Adicionar serviços `jaeger`, `prometheus` e `grafana` ao `docker-compose.yml` sob perfil `observability` (usando `profiles: [observability]`)
- [x] 7.4 Criar `docs/runbooks/observability-local.md` com: como iniciar a stack (`--profile observability`), URLs de acesso (Jaeger `:16686`, Grafana `:3000`, Prometheus `:9090`), configuração OTEL para .NET 8 (pacotes NuGet + snippet de Program.cs), como rastrear uma requisição E2E pelo `correlationId`

## 8. Diagramas C4 Nível 3 Faltantes

- [x] 8.1 Criar `docs/c4/meli-envios-checkout-domain-level3.puml` com componentes internos do CheckoutService (Controller, Application Service, Domain, Kafka Producer/Consumer, Infrastructure)
- [x] 8.2 Criar `docs/c4/meli-envios-shipping-promise-domain-level3.puml` com componentes do ShippingPromiseService e suas dependências síncronas
- [x] 8.3 Criar `docs/c4/meli-envios-order-saga-level3.puml` mostrando o OrderProcessManager e os tópicos internos de saga
- [x] 8.4 Executar `docker run --rm -v "$PWD:/work" plantuml/plantuml -tsvg /work/docs/c4/*.puml` para gerar os SVGs dos novos diagramas

## 9. Documentação de CI/CD

- [x] 9.1 Criar diretório `docs/cicd/`
- [x] 9.2 Criar `docs/cicd/pipeline.md` com: etapas obrigatórias do pipeline (restore → build → test → format → validar contratos → build Docker), template de workflow GitHub Actions para .NET 8, validação de YAML OpenAPI e PlantUML via Docker

## 10. Atualização de README e AGENTS.md

- [x] 10.1 Atualizar seção Estrutura do `README.md` para incluir `docs/reviews/`, `docs/runbooks/`, `docs/glossary/`, `docs/security/`, `docs/services/`, `docs/cicd/`
- [x] 10.2 Atualizar seção de ADRs do `README.md` para listar os novos ADRs (0002 a 0006)
- [x] 10.3 Atualizar `README.md` seção Contratos para incluir `docs/contracts/kafka-schema-governance.md`
- [x] 10.4 Revisar `AGENTS.md` para garantir que todas as novas referências (glossário, specs de serviço, governance, segurança) estão listadas como leitura obrigatória antes de gerar código
