# Logistica Marketplace Demo Architecture

Repositório de arquitetura e documentação do case **Logística Marketplace Demo**.

## Estado atual

Esta visão consolida os repositórios de frontend, BFF, microservices, endpoints REST, consumers/producers Kafka, persistência local, observabilidade e lacunas práticas observadas no código.

## O que este repo documenta

- Canal web do marketplace, BFF e microservices implementados.
- Contratos REST consolidados.
- Eventos e comandos Kafka usados na jornada.
- Carrinho efêmero no BFF com Redis e evento `cart.abandoned`.
- Saga de checkout, pedido, estoque, fulfillment, pagamento, shipment, tracking, notificação, auditoria e visibilidade operacional.
- Bancos, schemas, caches e padrões Inbox/Outbox.
- Logs, métricas e traces distribuídos.
- Diagramas C4, sequências e runbooks de validação local.

## Estrutura

```text
logistica-marketplace-demo-arch
├── docs/
│   ├── services/
│   ├── contracts/
│   ├── adr/
│   ├── diagrams/
│   ├── runbooks/
│   └── reviews/
├── monitoring/
├── database/
├── scripts/
├── docker-compose.yml
├── README.md
└── AGENTS.md
```

## Visão arquitetural

A plataforma simula uma arquitetura de marketplace baseada em:

- Microservices independentes.
- Event Driven Architecture (Kafka).
- Saga Orchestration.
- REST síncrono para consultas e composição.
- Inbox/Outbox para confiabilidade.
- OpenTelemetry para observabilidade.
- Postgres, Redis e Kafka como infraestrutura principal.

## Observabilidade

A observabilidade é tratada como requisito arquitetural de primeira classe.

### Logs

- Logs estruturados em JSON.
- Correlação por `CorrelationId`, `OrderId`, `CheckoutId` e `ShipmentId`.
- Centralização via Loki.
- Consulta operacional através do Grafana.

Objetivos:

- Investigação de incidentes.
- Auditoria operacional.
- Troubleshooting distribuído.
- Análise de falhas de saga.

### Métricas

Coletadas através de OpenTelemetry Metrics e Prometheus.

Exemplos:

- Checkouts iniciados.
- Checkouts confirmados.
- Pedidos criados.
- Pagamentos aprovados.
- Pagamentos rejeitados.
- Shipments criados.
- Tempo de resposta das APIs.
- Kafka consumer lag.
- Throughput por tópico.
- Taxa de erro por serviço.

Visualização realizada através do Grafana.

### Traces distribuídos

A plataforma utiliza OpenTelemetry Tracing e Jaeger.

Cada requisição pode ser acompanhada ponta a ponta através de:

- TraceId.
- SpanId.
- CorrelationId.

Exemplo de jornada rastreável:

```text
MarketplaceWeb
  -> MarketplaceWeb.Bff
  -> CheckoutService
  -> OrderService
  -> PaymentService
  -> ShipmentService
  -> TrackingService
```

O objetivo é permitir análise completa de latência, falhas e propagação entre APIs REST e eventos Kafka.

### Stack de observabilidade

```text
Application Logs
       |
      Loki
       |
    Grafana

Application Metrics
       |
   Prometheus
       |
    Grafana

Application Traces
       |
     Jaeger
```

### Observabilidade operacional

O repositório documenta cenários para:

- Troubleshooting de jornadas distribuídas.
- Correlação entre logs, métricas e traces.
- Monitoramento de consumidores Kafka.
- Identificação de gargalos de performance.
- Visualização de timelines de pedido.
- Investigação de falhas de integração.

## Repositórios envolvidos

Consulte [`docs/contracts/services-map.md`](docs/contracts/services-map.md) para a matriz completa de serviços, integrações e responsabilidades.

### Canais e composição

| Componente | Repositório | Responsabilidade | Specs |
|---|---|---|---|
| Marketplace Web | [`MarketplaceWeb`](https://github.com/leandrosflora/MarketplaceWeb) | Frontend web do marketplace | Contratos em [`docs/contracts/api-contract-validation.md`](docs/contracts/api-contract-validation.md) |
| Marketplace BFF | [`MarketplaceWeb.Bff`](https://github.com/leandrosflora/MarketplaceWeb.Bff) | Composição de APIs para o canal web, carrinho efêmero e orquestração síncrona com serviços de domínio | Contratos em [`docs/contracts/api-contract-validation.md`](docs/contracts/api-contract-validation.md) |

### Microservices principais

| Microservice | Repositório | Responsabilidade | Spec |
|---|---|---|---|
| Product Search Service | [`ProductSearchService`](https://github.com/leandrosflora/ProductSearchService) | Busca e paginação de produtos para descoberta no marketplace | [`docs/services/product-search-service.md`](docs/services/product-search-service.md) |
| Checkout Service | [`CheckoutService`](https://github.com/leandrosflora/CheckoutService) | Inicia checkout, recebe promise de entrega e confirma compra | [`docs/services/checkout-service.md`](docs/services/checkout-service.md) |
| Shipping Promise Service | [`ShippingPromiseService`](https://github.com/leandrosflora/ShippingPromiseService) | Calcula promessa de entrega, modalidade, prazo e custo logístico | [`docs/services/shipping-promise-service.md`](docs/services/shipping-promise-service.md) |
| Product Catalog Service | [`ProductCatalogService`](https://github.com/leandrosflora/ProductCatalogService) | Expõe atributos logísticos de SKU e catálogo operacional | [`docs/services/product-catalog-service.md`](docs/services/product-catalog-service.md) |
| Inventory Service | [`InventoryService`](https://github.com/leandrosflora/InventoryService) | Consulta, reserva, confirma e libera estoque | [`docs/services/inventory-service.md`](docs/services/inventory-service.md) |
| Fulfillment Center Service | [`FulfillmentCenterService`](https://github.com/leandrosflora/FulfillmentCenterService) | Informa capacidade, cutoff, operação e disponibilidade dos centros de fulfillment | [`docs/services/fulfillment-center-service.md`](docs/services/fulfillment-center-service.md) |
| Routing Service | [`RoutingService`](https://github.com/leandrosflora/RoutingService) | Calcula rotas logísticas, malha, hubs e janelas | [`docs/services/routing-service.md`](docs/services/routing-service.md) |
| Carrier Service | [`CarrierService`](https://github.com/leandrosflora/CarrierService) | Consulta disponibilidade, restrições e regras de transportadoras | [`docs/services/carrier-service.md`](docs/services/carrier-service.md) |
| Shipping Pricing Service | [`ShippingPricingService`](https://github.com/leandrosflora/ShippingPricingService) | Calcula frete, custo logístico, subsídio e promoções | [`docs/services/shipping-pricing-service.md`](docs/services/shipping-pricing-service.md) |
| Order Service | [`OrderService`](https://github.com/leandrosflora/OrderService) | Cria pedido e orquestra a saga de estoque, fulfillment, pagamento e envio | [`docs/services/order-service.md`](docs/services/order-service.md) |
| Payment Service | [`PaymentService`](https://github.com/leandrosflora/PaymentService) | Processa comandos de pagamento e publica autorização/captura/rejeição | [`docs/services/payment-service.md`](docs/services/payment-service.md) |
| Shipment Service | [`ShipmentService`](https://github.com/leandrosflora/ShipmentService) | Cria entrega física, pacote, etiqueta e despacho | [`docs/services/shipment-service.md`](docs/services/shipment-service.md) |
| Tracking Service | [`TrackingService`](https://github.com/leandrosflora/TrackingService) | Mantém timeline de rastreio e status de entrega | [`docs/services/tracking-service.md`](docs/services/tracking-service.md) |
| Notification Service | [`NotificationService`](https://github.com/leandrosflora/NotificationService) | Envia notificações de status, atrasos e mudanças da jornada | [`docs/services/notification-service.md`](docs/services/notification-service.md) |
| Audit Service | [`AuditService`](https://github.com/leandrosflora/AuditService) | Consome eventos canônicos e persiste auditoria operacional imutável | [`docs/services/audit-service.md`](docs/services/audit-service.md) |
| Order Visibility Service | [`OrderVisibilityService`](https://github.com/leandrosflora/OrderVisibilityService) | Projeta eventos da jornada para consulta operacional e visibilidade do pedido | [`docs/services/order-visibility-service.md`](docs/services/order-visibility-service.md) |

## Kafka em prática

Contrato consolidado em `docs/contracts/kafka-events.md`.

Principais fluxos:

- Checkout → Shipping Promise.
- Checkout → Order.
- Order → Inventory/Fulfillment.
- Order → Payment.
- Order → Shipment.
- Shipment → Tracking.
- Cart → Notification (`cart.abandoned`).
- Audit e Order Visibility consumindo eventos da jornada.

## Dados e bancos

Matriz canônica: `docs/contracts/data-stores.md`.

| Recurso | Uso |
|---|---|
| Postgres | Persistência transacional e read models |
| Redis | Cache e carrinho efêmero |
| Kafka | Eventos e comandos |
| Prometheus | Métricas |
| Grafana | Dashboards |
| Loki | Logs centralizados |
| Jaeger | Traces distribuídos |
| SignalR | Atualização em tempo real |

## Contratos

- docs/contracts/services-map.md
- docs/contracts/data-stores.md
- docs/contracts/kafka-events.md
- docs/contracts/api-contract-validation.md
- docs/contracts/kafka-schema-governance.md

## Segurança

- docs/security/security-architecture.md

## ADRs

- Event Driven Architecture
- Saga Orchestration
- Hexagonal Architecture
- Kafka Schema Versioning
- Idempotency Strategy
- Observability Stack

## Runbooks

- docs/runbooks/kafka-local-e2e.md
- docs/runbooks/observability-local.md
- docs/runbooks/order-visibility-local.md

## Licença

Apache License 2.0
