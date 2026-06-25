# Logística Envios Demo Architecture

Repositório de arquitetura e documentação do case **Logística de Envios**.

## Estado atual

Status: **documentação alinhada ao código atual dos microservices em 2026-06-25**.

Esta revisão reflete os repositórios de microservices existentes, seus endpoints reais, tópicos Kafka registrados, padrões de persistência e lacunas atuais.

## O que este repo documenta

- Microservices implementados.
- Contratos REST consolidados.
- Eventos e comandos Kafka efetivamente configurados.
- Lacunas da saga atual.
- Dados, bancos, caches e padrões Inbox/Outbox.
- Diagramas C4 e fluxos de referência.
- Runbooks de validação local.

## Estrutura

```text
logistica-envios-demo-arch
├── docs/
│   ├── adr/                    # Decisões arquiteturais
│   ├── c4/                     # Diagramas C4 (PlantUML + SVG)
│   ├── cicd/                   # Pipeline CI/CD
│   ├── contracts/              # Contratos REST, Kafka, dados e schema governance
│   ├── glossary/               # Glossário de domínio
│   ├── prompts/                # Prompts para Codex
│   ├── reviews/                # Reviews e validações
│   ├── runbooks/               # Runbooks de operação local
│   ├── security/               # Arquitetura de segurança
│   ├── sequence-diagrams/      # Diagramas de sequência
│   └── services/               # Specs individuais de microservice
├── monitoring/                 # Prometheus/Grafana local
├── docker-compose.yml
├── README.md
└── AGENTS.md
```

## Repositórios envolvidos

### Canal e BFF

| Componente | Repositório |
|---|---|
| Frontend | [MarketplaceWeb](https://github.com/leandrosflora/MarketplaceWeb) |
| BFF | [MarketplaceWeb.Bff](https://github.com/leandrosflora/MarketplaceWeb.Bff) |

### Microservices implementados

| Microservice | Repositório | Responsabilidade prática |
|---|---|---|
| Checkout Service | [CheckoutService](https://github.com/leandrosflora/CheckoutService) | Cria, consulta e confirma sessões de checkout; publica eventos de checkout. |
| Product Search Service | [ProductSearchService](https://github.com/leandrosflora/ProductSearchService) | Busca produtos ativos em read model Postgres para alimentar BFF/frontend. |
| Shipping Promise Service | [ShippingPromiseService](https://github.com/leandrosflora/ShippingPromiseService) | Calcula promessa de entrega consultando catálogo, estoque, fulfillment, rota, carrier e pricing. |
| Product Catalog Service | [ProductCatalogService](https://github.com/leandrosflora/ProductCatalogService) | Expõe atributos logísticos de SKU. |
| Inventory Service | [InventoryService](https://github.com/leandrosflora/InventoryService) | Consulta disponibilidade e gerencia reservas de estoque. |
| Fulfillment Center Service | [FulfillmentCenterService](https://github.com/leandrosflora/FulfillmentCenterService) | Gerencia centros, capacidade, status e reservas operacionais. |
| Routing Service | [RoutingService](https://github.com/leandrosflora/RoutingService) | Calcula rotas logísticas e mantém grafo de malha. |
| Carrier Service | [CarrierService](https://github.com/leandrosflora/CarrierService) | Gerencia transportadoras, níveis de serviço, lanes e disponibilidade. |
| Shipping Pricing Service | [ShippingPricingService](https://github.com/leandrosflora/ShippingPricingService) | Calcula frete, quotes e rate cards. |
| Order Service | [OrderService](https://github.com/leandrosflora/OrderService) | Cria pedido a partir de checkout confirmado e orquestra a saga por Kafka/outbox. |
| Shipment Service | [ShipmentService](https://github.com/leandrosflora/ShipmentService) | Cria shipment, pacotes, etiqueta e comandos para carrier. |
| Tracking Service | [TrackingService](https://github.com/leandrosflora/TrackingService) | Mantém timeline/status de entrega e publica atualizações de tracking. |
| Notification Service | [NotificationService](https://github.com/leandrosflora/NotificationService) | Planeja e envia notificações Email/SMS/Push com preferências e receipts. |

### Componentes não implementados como microservice

| Componente | Situação |
|---|---|
| Payment Service | Não há repo/microservice implementado. O `OrderService` escreve `payment.commands`, mas não existe consumer real no conjunto atual. |
| Audit Service | Não há repo/microservice implementado. Foi removido da visão implementada. |

## Specs de serviços

Documentação detalhada por microservice em [`docs/services/`](docs/services/).

| Serviço | Spec |
|---|---|
| Checkout Service | [spec](docs/services/checkout-service.md) |
| Product Search Service | [spec](docs/services/product-search-service.md) |
| Shipping Promise Service | [spec](docs/services/shipping-promise-service.md) |
| Product Catalog Service | [spec](docs/services/product-catalog-service.md) |
| Inventory Service | [spec](docs/services/inventory-service.md) |
| Fulfillment Center Service | [spec](docs/services/fulfillment-center-service.md) |
| Routing Service | [spec](docs/services/routing-service.md) |
| Carrier Service | [spec](docs/services/carrier-service.md) |
| Shipping Pricing Service | [spec](docs/services/shipping-pricing-service.md) |
| Order Service | [spec](docs/services/order-service.md) |
| Shipment Service | [spec](docs/services/shipment-service.md) |
| Tracking Service | [spec](docs/services/tracking-service.md) |
| Notification Service | [spec](docs/services/notification-service.md) |

## Principais correções desta revisão

| Tema | Correção |
|---|---|
| Payment Service | Removido como microservice implementado; mantido apenas como lacuna/dependência de `payment.commands`. |
| Audit Service | Removido da visão implementada. |
| Product Search | Corrigido de OpenSearch para Postgres read model atual. |
| Order Service | Corrigido: criação de pedido ocorre via `checkout.confirmed`, não via `POST /v1/orders`. |
| Shipment Service | Corrigido: endpoints não usam `/v1`; cancelamento escreve `carrier-shipment.commands`, não `shipment.cancelled`. |
| Kafka | Separado entre implementado, parcial, produzido sem consumidor e configurado sem producer. |
| OpenAPI | Contratos REST consolidados atualizados para refletir endpoints reais observados no código. |

## Kafka em prática

Contrato consolidado: [`docs/contracts/kafka-events.md`](docs/contracts/kafka-events.md).

| Fluxo | Status |
|---|---|
| Checkout → Shipping Promise → Checkout | Implementado |
| Checkout Confirmed → Order | Implementado |
| Order → Inventory/Fulfillment | Implementado |
| Order → Payment | Parcial; `payment.commands` é produzido, mas não há consumer implementado |
| Order/Shipment → Tracking | Implementado |
| Tracking/Order/Shipment → Notification | Parcial; há consumers configurados para tópicos sem producer atual |
| Auditoria centralizada | Não implementada como microservice |

## Dados e bancos

Matriz canônica: [`docs/contracts/data-stores.md`](docs/contracts/data-stores.md).

| Recurso | Convenção prática |
|---|---|
| Postgres local | Banco compartilhado por schemas/connections conforme cada microservice |
| Redis | Usado apenas por serviços que registram Redis no bootstrap |
| Kafka | Eventos/comandos conforme implementação atual |
| Outbox | Implementado nos serviços produtores conforme código |
| Inbox | Implementado nos serviços consumidores conforme código |

## Fluxos principais

### Promise assíncrona

```text
CheckoutService
  -> checkout.shipping.quote.requested
  -> ShippingPromiseService
  -> shipping.promise.calculated
  -> CheckoutService
```

### Pedido e saga parcial

```text
CheckoutService
  -> checkout.confirmed
  -> OrderService
  -> order.created
  -> inventory.commands / fulfillment.commands
  -> InventoryService / FulfillmentCenterService
  -> inventory.* / fulfillment.*
  -> OrderService
  -> payment.commands
  -> [lacuna: PaymentService não implementado]
  -> shipment.commands / order.events
  -> ShipmentService
  -> shipment.created
  -> TrackingService / NotificationService
  -> shipment.status.updated
  -> OrderService / NotificationService
```

## Contratos

- [`docs/contracts/README.md`](docs/contracts/README.md)
- [`docs/contracts/services-map.md`](docs/contracts/services-map.md)
- [`docs/contracts/data-stores.md`](docs/contracts/data-stores.md)
- [`docs/contracts/logistica-envios-apis.openapi.yaml`](docs/contracts/logistica-envios-apis.openapi.yaml)
- [`docs/contracts/api-contract-validation.md`](docs/contracts/api-contract-validation.md)
- [`docs/contracts/kafka-events.md`](docs/contracts/kafka-events.md)
- [`docs/contracts/kafka-schema-governance.md`](docs/contracts/kafka-schema-governance.md)

## Segurança

- [`docs/security/security-architecture.md`](docs/security/security-architecture.md)

## Diagramas

### C4

- Fonte: [`docs/c4/logistica-envios-context.puml`](docs/c4/logistica-envios-context.puml)
- Imagem: [`docs/c4/logistica-envios-context.svg`](docs/c4/logistica-envios-context.svg)
- Fonte: [`docs/c4/logistica-envios-container.puml`](docs/c4/logistica-envios-container.puml)
- Imagem: [`docs/c4/logistica-envios-container.svg`](docs/c4/logistica-envios-container.svg)

> O PlantUML fonte foi atualizado nesta revisão. SVGs podem ser regenerados pelo workflow de renderização.

## ADRs

- [`docs/adr/0001-use-event-driven-architecture.md`](docs/adr/0001-use-event-driven-architecture.md)
- [`docs/adr/0002-saga-orchestrator-pattern.md`](docs/adr/0002-saga-orchestrator-pattern.md)
- [`docs/adr/0003-hexagonal-clean-architecture.md`](docs/adr/0003-hexagonal-clean-architecture.md)
- [`docs/adr/0004-kafka-schema-versioning.md`](docs/adr/0004-kafka-schema-versioning.md)
- [`docs/adr/0005-idempotency-strategy.md`](docs/adr/0005-idempotency-strategy.md)
- [`docs/adr/0006-observability-stack.md`](docs/adr/0006-observability-stack.md)
- [`docs/adr/0007-order-service-internal-saga-topics.md`](docs/adr/0007-order-service-internal-saga-topics.md)

## Runbooks e revisões

- [`docs/runbooks/kafka-local-e2e.md`](docs/runbooks/kafka-local-e2e.md)
- [`docs/runbooks/observability-local.md`](docs/runbooks/observability-local.md)
- [`docs/reviews/microservices-code-alignment-2026-06-25.md`](docs/reviews/microservices-code-alignment-2026-06-25.md)

## Licença

Este repositório está licenciado sob a **Apache License 2.0**. Consulte o arquivo [LICENSE](LICENSE) para detalhes.
