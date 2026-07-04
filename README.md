# Logistica Marketplace Demo Architecture

Repositório de arquitetura e documentação do case **Logística Marketplace Demo**.

## Estado atual

Status: **documentação alinhada à implementação atual dos microservices em 2026-07-04**.

Esta visão consolida os repositórios de frontend, BFF, microservices, endpoints REST, consumers/producers Kafka, persistência local, observabilidade e lacunas práticas observadas no código.

## O que este repo documenta

- Canal web do marketplace, BFF e microservices implementados.
- Contratos REST consolidados.
- Eventos e comandos Kafka usados na jornada.
- Carrinho efêmero no BFF com Redis e evento `cart.abandoned`.
- Saga de checkout, pedido, estoque, fulfillment, pagamento, shipment, tracking, notificação, auditoria e visibilidade operacional.
- Bancos, schemas, caches e padrões Inbox/Outbox.
- Diagramas C4, sequências e runbooks de validação local.

## Estrutura

```text
logistica-marketplace-demo-arch
├── docs/
│   ├── adr/                    # Decisões arquiteturais
│   ├── c4/                     # Diagramas C4 (PlantUML + SVG)
│   ├── cicd/                   # Pipeline CI/CD
│   ├── contracts/              # Contratos REST, Kafka, dados e schema governance
│   ├── glossary/               # Glossário de domínio
│   ├── prompts/                # Prompts para Codex/agents
│   ├── reviews/                # Reviews e validações
│   ├── runbooks/               # Runbooks de operação local
│   ├── security/               # Arquitetura de segurança
│   ├── sequence-diagrams/      # Diagramas de sequência
│   └── services/               # Specs individuais de microservice
├── monitoring/                 # Prometheus/Grafana local
├── database/                   # Seed/schema local Postgres
├── scripts/                    # Scripts auxiliares de demo
├── docker-compose.yml
├── README.md
└── AGENTS.md
```

## Repositórios envolvidos

### Canal e BFF

| Componente | Repositório | Responsabilidade |
|---|---|---|
| Frontend | [MarketplaceWeb](https://github.com/leandrosflora/MarketplaceWeb) | Experiência web do marketplace e telas operacionais. |
| BFF | [MarketplaceWeb.Bff](https://github.com/leandrosflora/MarketplaceWeb.Bff) | Agregação para o canal web, carrinho em Redis, chamadas aos microservices e publicação de `cart.abandoned`. |

### Microservices implementados

| Microservice | Repositório | Responsabilidade prática |
|---|---|---|
| Product Search Service | [ProductSearchService](https://github.com/leandrosflora/ProductSearchService) | Busca produtos ativos em read model Postgres para alimentar BFF/frontend. |
| Checkout Service | [CheckoutService](https://github.com/leandrosflora/CheckoutService) | Cria, consulta e confirma sessões de checkout; publica eventos de checkout. |
| Shipping Promise Service | [ShippingPromiseService](https://github.com/leandrosflora/ShippingPromiseService) | Calcula promessa de entrega via APIs de catálogo, estoque, fulfillment, rota, carrier e pricing. |
| Product Catalog Service | [ProductCatalogService](https://github.com/leandrosflora/ProductCatalogService) | Expõe atributos logísticos de SKU. |
| Inventory Service | [InventoryService](https://github.com/leandrosflora/InventoryService) | Consulta disponibilidade e gerencia reservas de estoque. |
| Fulfillment Center Service | [FulfillmentCenterService](https://github.com/leandrosflora/FulfillmentCenterService) | Gerencia centros, capacidade, status e reservas operacionais. |
| Routing Service | [RoutingService](https://github.com/leandrosflora/RoutingService) | Calcula rotas logísticas e mantém grafo de malha. |
| Carrier Service | [CarrierService](https://github.com/leandrosflora/CarrierService) | Gerencia transportadoras, níveis de serviço, lanes e disponibilidade. |
| Shipping Pricing Service | [ShippingPricingService](https://github.com/leandrosflora/ShippingPricingService) | Calcula frete, quotes e rate cards. |
| Order Service | [OrderService](https://github.com/leandrosflora/OrderService) | Cria pedido a partir de `checkout.confirmed` e orquestra a saga por Kafka/outbox. |
| Payment Service | [PaymentService](https://github.com/leandrosflora/PaymentService) | Consome `payment.commands` e publica eventos de autorização/captura de pagamento com gateway mock determinístico. |
| Shipment Service | [ShipmentService](https://github.com/leandrosflora/ShipmentService) | Cria shipment, pacotes, etiqueta e comandos para carrier. |
| Tracking Service | [TrackingService](https://github.com/leandrosflora/TrackingService) | Mantém timeline/status de entrega e publica atualizações de tracking. |
| Notification Service | [NotificationService](https://github.com/leandrosflora/NotificationService) | Planeja e envia notificações Email/SMS/Push com preferências e receipts. |
| Audit Service | [AuditService](https://github.com/leandrosflora/AuditService) | Consome eventos canônicos com producer real e persiste auditoria imutável. |
| Order Visibility Service | [OrderVisibilityService](https://github.com/leandrosflora/OrderVisibilityService) | Consome eventos da jornada, materializa timeline/status operacional e expõe REST + SignalR. |

### Dependências externas ou pendentes

| Componente | Situação |
|---|---|
| Gateway/PSP de pagamento | Não há gateway real; `PaymentService` usa adapter mock determinístico. |
| Integração carrier shipment | `ShipmentService` escreve `carrier-shipment.commands`, mas não há consumer dedicado documentado neste conjunto. |
| Eventos canônicos de ordem/cancelamento | `NotificationService` espera `order.confirmed`, `order.cancelled` e `shipment.cancelled`; os producers canônicos ainda não estão implementados. |
| Carrinho abandonado anônimo | `MarketplaceWeb.Bff` pode publicar `cart.abandoned` com `buyerId = null`; `NotificationService` consome sem envio por falta de destinatário conhecido. |

## Specs de serviços

Documentação detalhada por microservice em [`docs/services/`](docs/services/).

| Serviço | Spec |
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

## Kafka em prática

Contrato consolidado: [`docs/contracts/kafka-events.md`](docs/contracts/kafka-events.md).

| Fluxo | Status |
|---|---|
| Checkout -> Shipping Promise -> Checkout | Implementado com `checkout.shipping.quote.requested` e `shipping.promise.calculated`. |
| Checkout Confirmed -> Order | Implementado com `checkout.confirmed`. |
| Order -> Inventory/Fulfillment | Implementado com `inventory.commands`, `fulfillment.commands` e eventos de reserva/confirmação/falha. |
| Order -> Payment -> Order | Implementado com `payment.commands`, `payment.approved`, `payment.rejected`, `payment.captured` e `payment.capture.failed`. |
| Order -> Shipment -> Tracking | Implementado com `shipment.commands`, `shipment.created`, `shipment.creation.failed` e `shipment.status.updated`. |
| Cart abandonment | Implementado com `cart.abandoned`, produzido diretamente pelo `MarketplaceWeb.Bff` e consumido pelo `NotificationService`. |
| Notification | Parcial: consome eventos reais como `order.created`, `payment.rejected`, `shipment.created`, `shipment.status.updated` e `cart.abandoned`, mas também configura tópicos sem producer canônico atual. |
| Audit | Implementado como consumer-only dos eventos canônicos com producer real. |
| Order Visibility | Implementado como consumer-only dos fatos da jornada; não consome tópicos `*.commands` e não publica Kafka. |
| Carrier shipment | Pendente: `carrier-shipment.commands` é produzido, mas não há consumer dedicado no conjunto atual. |

### Eventos canônicos auditados

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

### Tópicos internos, efêmeros ou pendentes

| Tópico | Situação |
|---|---|
| `inventory.commands` | Comando interno da saga, produzido por `OrderService` e consumido por `InventoryService`. |
| `fulfillment.commands` | Comando interno da saga, produzido por `OrderService` e consumido por `FulfillmentCenterService`. |
| `payment.commands` | Comando interno da saga, produzido por `OrderService` e consumido por `PaymentService`. |
| `shipment.commands` | Comando interno da saga, produzido por `OrderService` e consumido por `ShipmentService`. |
| `order.events` | Tópico interno/controlado do `OrderService` para confirmação/cancelamento. |
| `cart.abandoned` | Evento de UX/retargeting produzido pelo BFF sem outbox; aceitável por ser dado efêmero de carrinho, não fato financeiro/logístico. |
| `carrier-shipment.commands` | Produzido por `ShipmentService`; consumer dedicado pendente. |
| `order.confirmed`, `order.cancelled`, `shipment.cancelled` | Configurados em consumidores de notificação, mas sem producer canônico atual. |

## Fluxos principais

### Descoberta de produto e carrinho

```text
MarketplaceWeb
  -> MarketplaceWeb.Bff
  -> ProductSearchService
  -> MarketplaceWeb.Bff
  -> Redis cart:<cartOwnerId>
  -> cart.abandoned
  -> NotificationService
```

### Promise assíncrona

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

Matriz canônica: [`docs/contracts/data-stores.md`](docs/contracts/data-stores.md).

| Recurso | Convenção prática |
|---|---|
| Postgres local | Banco compartilhado por schemas/connections conforme ownership de cada microservice. |
| Redis | Cache local para serviços que registram Redis no bootstrap; também usado pelo BFF para carrinho efêmero com chave `cart:<cartOwnerId>`. |
| Kafka | Eventos e comandos conforme implementação atual. |
| Outbox | Usado nos produtores de eventos/comandos quando implementado. Não é usado para `cart.abandoned`. |
| Inbox | Usado nos consumidores para idempotência quando implementado. |
| SignalR | Usado pelo `OrderVisibilityService` para atualização operacional em tempo real. |

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

> Os SVGs podem ser regenerados pelo workflow de renderização.

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
- [`docs/runbooks/order-visibility-local.md`](docs/runbooks/order-visibility-local.md)
- Histórico: [`docs/reviews/microservices-code-alignment-2026-06-25.md`](docs/reviews/microservices-code-alignment-2026-06-25.md). A leitura sobre `PaymentService` e `AuditService` foi superada pela implementação atual.

## Licença

Este repositório está licenciado sob a **Apache License 2.0**. Consulte o arquivo [LICENSE](LICENSE) para detalhes.
