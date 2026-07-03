# Logistica Envios Demo Architecture

Repositorio de arquitetura e documentacao do case **Logistica de Envios**.

## Estado atual

Status: **documentacao alinhada a implementacao atual dos microservices em 2026-07-02**.

Esta visao reflete os repositorios de microservices, endpoints REST, consumers/producers Kafka, persistencia local e lacunas praticas observadas no codigo.

## O que este repo documenta

- Canal web, BFF e microservices implementados.
- Contratos REST consolidados.
- Eventos e comandos Kafka usados na jornada.
- Saga de pedido, pagamento, shipment, tracking, notificacao, auditoria e visibilidade operacional.
- Bancos, schemas e padroes Inbox/Outbox.
- Diagramas C4, sequencias e runbooks de validacao local.

## Estrutura

```text
logistica-envios-demo-arch
├── docs/
│   ├── adr/                    # Decisoes arquiteturais
│   ├── c4/                     # Diagramas C4 (PlantUML + SVG)
│   ├── cicd/                   # Pipeline CI/CD
│   ├── contracts/              # Contratos REST, Kafka, dados e schema governance
│   ├── glossary/               # Glossario de dominio
│   ├── prompts/                # Prompts para Codex
│   ├── reviews/                # Reviews e validacoes
│   ├── runbooks/               # Runbooks de operacao local
│   ├── security/               # Arquitetura de seguranca
│   ├── sequence-diagrams/      # Diagramas de sequencia
│   └── services/               # Specs individuais de microservice
├── monitoring/                 # Prometheus/Grafana local
├── database/                   # Seed/schema local Postgres
├── scripts/                    # Scripts auxiliares de demo
├── docker-compose.yml
├── README.md
└── AGENTS.md
```

## Repositorios envolvidos

### Canal e BFF

| Componente | Repositorio | Responsabilidade |
|---|---|---|
| Frontend | [MarketplaceWeb](https://github.com/leandrosflora/MarketplaceWeb) | Experiencia web do marketplace e telas operacionais. |
| BFF | [MarketplaceWeb.Bff](https://github.com/leandrosflora/MarketplaceWeb.Bff) | Agregacao para o canal web e chamadas aos microservices. |

### Microservices implementados

| Microservice | Repositorio | Responsabilidade pratica |
|---|---|---|
| Product Search Service | [ProductSearchService](https://github.com/leandrosflora/ProductSearchService) | Busca produtos ativos em read model Postgres para alimentar BFF/frontend. |
| Checkout Service | [CheckoutService](https://github.com/leandrosflora/CheckoutService) | Cria, consulta e confirma sessoes de checkout; publica eventos de checkout. |
| Shipping Promise Service | [ShippingPromiseService](https://github.com/leandrosflora/ShippingPromiseService) | Calcula promessa de entrega via APIs de catalogo, estoque, fulfillment, rota, carrier e pricing. |
| Product Catalog Service | [ProductCatalogService](https://github.com/leandrosflora/ProductCatalogService) | Expoe atributos logisticos de SKU. |
| Inventory Service | [InventoryService](https://github.com/leandrosflora/InventoryService) | Consulta disponibilidade e gerencia reservas de estoque. |
| Fulfillment Center Service | [FulfillmentCenterService](https://github.com/leandrosflora/FulfillmentCenterService) | Gerencia centros, capacidade, status e reservas operacionais. |
| Routing Service | [RoutingService](https://github.com/leandrosflora/RoutingService) | Calcula rotas logisticas e mantem grafo de malha. |
| Carrier Service | [CarrierService](https://github.com/leandrosflora/CarrierService) | Gerencia transportadoras, niveis de servico, lanes e disponibilidade. |
| Shipping Pricing Service | [ShippingPricingService](https://github.com/leandrosflora/ShippingPricingService) | Calcula frete, quotes e rate cards. |
| Order Service | [OrderService](https://github.com/leandrosflora/OrderService) | Cria pedido a partir de `checkout.confirmed` e orquestra a saga por Kafka/outbox. |
| Payment Service | [PaymentService](https://github.com/leandrosflora/PaymentService) | Consome `payment.commands` e publica eventos de autorizacao/captura de pagamento com gateway mock deterministico. |
| Shipment Service | [ShipmentService](https://github.com/leandrosflora/ShipmentService) | Cria shipment, pacotes, etiqueta e comandos para carrier. |
| Tracking Service | [TrackingService](https://github.com/leandrosflora/TrackingService) | Mantem timeline/status de entrega e publica atualizacoes de tracking. |
| Notification Service | [NotificationService](https://github.com/leandrosflora/NotificationService) | Planeja e envia notificacoes Email/SMS/Push com preferencias e receipts. |
| Audit Service | [AuditService](https://github.com/leandrosflora/AuditService) | Consome eventos canonicos com producer real e persiste auditoria imutavel. |
| Order Visibility Service | [OrderVisibilityService](https://github.com/leandrosflora/OrderVisibilityService) | Consome eventos da jornada, materializa timeline/status operacional e expoe REST + SignalR. |

### Dependencias externas ou pendentes

| Componente | Situacao |
|---|---|
| Gateway/PSP de pagamento | Nao ha gateway real; `PaymentService` usa adapter mock. |
| Integracao carrier shipment | `ShipmentService` escreve `carrier-shipment.commands`, mas nao ha consumer dedicado documentado neste conjunto. |
| Eventos canonicos de ordem/cancelamento | `NotificationService` espera `order.confirmed`, `order.cancelled` e `shipment.cancelled`; os producers canonicos ainda nao estao implementados. |

## Specs de servicos

Documentacao detalhada por microservice em [`docs/services/`](docs/services/).

| Servico | Spec |
|---|---|
| Product Search Service | [spec](docs/services/product-search-service.md) |
| Checkout Service | [spec](docs/services/checkout-service.md) |
| Shipping Promise Service | [spec](docs/services/shipping-promise-service.md) |
| Product Catalog Service | [spec](docs/services/product-catalog-service.md) |
| Inventory Service | [spec](docs/services/inventory-service.md) |
| Fulfillment Center Service | [spec](docs/services/fulfillment-center-service.md) |
| Routing Service | [spec](docs/services/routing-service.md) |
| Carrier Service | [spec](docs/services/carrier-service.md) |
| Shipping Pricing Service | [spec](docs/services/shipping-pricing-service.md) |
| Order Service | [spec](docs/services/order-service.md) |
| Payment Service | [spec](docs/services/payment-service.md) |
| Shipment Service | [spec](docs/services/shipment-service.md) |
| Tracking Service | [spec](docs/services/tracking-service.md) |
| Notification Service | [spec](docs/services/notification-service.md) |
| Audit Service | [spec](docs/services/audit-service.md) |
| Order Visibility Service | [spec](docs/services/order-visibility-service.md) |

## Kafka em pratica

Contrato consolidado: [`docs/contracts/kafka-events.md`](docs/contracts/kafka-events.md).

| Fluxo | Status |
|---|---|
| Checkout -> Shipping Promise -> Checkout | Implementado com `checkout.shipping.quote.requested` e `shipping.promise.calculated`. |
| Checkout Confirmed -> Order | Implementado com `checkout.confirmed`. |
| Order -> Inventory/Fulfillment | Implementado com `inventory.commands`, `fulfillment.commands` e eventos de reserva/confirmacao/falha. |
| Order -> Payment -> Order | Implementado com `payment.commands`, `payment.approved`, `payment.rejected`, `payment.captured` e `payment.capture.failed`. |
| Order -> Shipment -> Tracking | Implementado com `shipment.commands`, `shipment.created`, `shipment.creation.failed` e `shipment.status.updated`. |
| Notification | Parcial: consome eventos reais como `order.created`, `payment.rejected`, `shipment.created` e `shipment.status.updated`, mas tambem configura topicos sem producer canonico atual. |
| Audit | Implementado como consumer-only dos dez eventos canonicos com producer real. |
| Order Visibility | Implementado como consumer-only dos fatos da jornada; nao consome topicos `*.commands` e nao publica Kafka. |
| Carrier shipment | Pendente: `carrier-shipment.commands` e produzido, mas nao ha consumer dedicado no conjunto atual. |

### Eventos canonicos auditados

`AuditService` consome:

- `checkout.shipping.quote.requested`
- `shipping.promise.calculated`
- `checkout.confirmed`
- `order.created`
- `payment.approved`
- `payment.rejected`
- `payment.captured`
- `payment.capture.failed`
- `shipment.created`
- `shipment.status.updated`

### Topicos internos ou pendentes

| Topico | Situacao |
|---|---|
| `inventory.commands` | Comando interno da saga, produzido por `OrderService` e consumido por `InventoryService`. |
| `fulfillment.commands` | Comando interno da saga, produzido por `OrderService` e consumido por `FulfillmentCenterService`. |
| `payment.commands` | Comando interno da saga, produzido por `OrderService` e consumido por `PaymentService`. |
| `shipment.commands` | Comando interno da saga, produzido por `OrderService` e consumido por `ShipmentService`. |
| `order.events` | Topico interno/controlado do `OrderService` para confirmacao/cancelamento. |
| `carrier-shipment.commands` | Produzido por `ShipmentService`; consumer dedicado pendente. |
| `order.confirmed`, `order.cancelled`, `shipment.cancelled` | Configurados em consumidores de notificacao, mas sem producer canonico atual. |

## Fluxos principais

### Promise assincrona

```text
CheckoutService
  -> checkout.shipping.quote.requested
  -> ShippingPromiseService
  -> shipping.promise.calculated
  -> CheckoutService
```

### Pedido, pagamento e entrega

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
  -> PaymentService
  -> payment.approved / payment.rejected / payment.captured / payment.capture.failed
  -> OrderService
  -> shipment.commands / order.events
  -> ShipmentService
  -> shipment.created / shipment.creation.failed
  -> TrackingService / NotificationService / AuditService / OrderVisibilityService
  -> shipment.status.updated
  -> OrderService / NotificationService / AuditService / OrderVisibilityService
```

## Dados e bancos

Matriz canonica: [`docs/contracts/data-stores.md`](docs/contracts/data-stores.md).

| Recurso | Convencao pratica |
|---|---|
| Postgres local | Banco compartilhado por schemas/connections conforme ownership de cada microservice. |
| Redis | Usado apenas por servicos que registram Redis no bootstrap. |
| Kafka | Eventos e comandos conforme implementacao atual. |
| Outbox | Usado nos produtores de eventos/comandos quando implementado. |
| Inbox | Usado nos consumidores para idempotencia quando implementado. |
| SignalR | Usado pelo `OrderVisibilityService` para atualizacao operacional em tempo real. |

## Contratos

- [`docs/contracts/README.md`](docs/contracts/README.md)
- [`docs/contracts/services-map.md`](docs/contracts/services-map.md)
- [`docs/contracts/data-stores.md`](docs/contracts/data-stores.md)
- [`docs/contracts/logistica-envios-apis.openapi.yaml`](docs/contracts/logistica-envios-apis.openapi.yaml)
- [`docs/contracts/api-contract-validation.md`](docs/contracts/api-contract-validation.md)
- [`docs/contracts/kafka-events.md`](docs/contracts/kafka-events.md)
- [`docs/contracts/kafka-schema-governance.md`](docs/contracts/kafka-schema-governance.md)

## Seguranca

- [`docs/security/security-architecture.md`](docs/security/security-architecture.md)

## Diagramas

### C4

- Fonte: [`docs/c4/logistica-envios-context.puml`](docs/c4/logistica-envios-context.puml)
- Imagem: [`docs/c4/logistica-envios-context.svg`](docs/c4/logistica-envios-context.svg)
- Fonte: [`docs/c4/logistica-envios-container.puml`](docs/c4/logistica-envios-container.puml)
- Imagem: [`docs/c4/logistica-envios-container.svg`](docs/c4/logistica-envios-container.svg)

> Os SVGs podem ser regenerados pelo workflow de renderizacao.

## ADRs

- [`docs/adr/0001-use-event-driven-architecture.md`](docs/adr/0001-use-event-driven-architecture.md)
- [`docs/adr/0002-saga-orchestrator-pattern.md`](docs/adr/0002-saga-orchestrator-pattern.md)
- [`docs/adr/0003-hexagonal-clean-architecture.md`](docs/adr/0003-hexagonal-clean-architecture.md)
- [`docs/adr/0004-kafka-schema-versioning.md`](docs/adr/0004-kafka-schema-versioning.md)
- [`docs/adr/0005-idempotency-strategy.md`](docs/adr/0005-idempotency-strategy.md)
- [`docs/adr/0006-observability-stack.md`](docs/adr/0006-observability-stack.md)
- [`docs/adr/0007-order-service-internal-saga-topics.md`](docs/adr/0007-order-service-internal-saga-topics.md)

## Runbooks e revisoes

- [`docs/runbooks/kafka-local-e2e.md`](docs/runbooks/kafka-local-e2e.md)
- [`docs/runbooks/observability-local.md`](docs/runbooks/observability-local.md)
- [`docs/runbooks/order-visibility-local.md`](docs/runbooks/order-visibility-local.md)
- Historico: [`docs/reviews/microservices-code-alignment-2026-06-25.md`](docs/reviews/microservices-code-alignment-2026-06-25.md). A leitura sobre `PaymentService` e `AuditService` foi superada pela implementacao atual.

## Licenca

Este repositorio esta licenciado sob a **Apache License 2.0**. Consulte o arquivo [LICENSE](LICENSE) para detalhes.
