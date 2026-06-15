# Logística Envios Demo Architecture

Repositório de arquitetura para estudo do case **Logística de Envios** (versão demo).

Objetivo: dar contexto suficiente para o Codex entender o domínio, os microservices, os contratos, os eventos Kafka, os diagramas C4, as decisões arquiteturais e os comandos de validação local.

## Licença

Este repositório e todos os seus conteúdos são proprietários e confidenciais (All Rights Reserved). Nenhuma parte deste repositório pode ser copiada, reproduzida, transmitida ou utilizada sem permissão expressa do proprietário.

## Estado atual

Status: **pronto para validação E2E local por fases**.

Os contratos Kafka canônicos foram alinhados entre os microservices principais. A execução final ainda deve ser validada localmente ou em CI com:

```bash
dotnet restore
dotnet build
dotnet test
docker compose up -d
```

## Estrutura

```text
logistica-envios-demo-arch
├── docs/
│   ├── adr/
│   ├── c4/
│   ├── contracts/
│   ├── prompts/
│   ├── reviews/
│   ├── runbooks/
│   └── sequence-diagrams/
├── docker-compose.yml
├── README.md
└── AGENTS.md
```

## Domínio

Este case modela uma plataforma de cálculo de frete, promessa de entrega, disponibilidade logística, criação de shipment, rastreio e notificação para milhões de pedidos por dia.

## Repositórios envolvidos

### Canal e BFF

| Componente | Repositório |
|---|---|
| Frontend | [MarketplaceWeb](https://github.com/leandrosflora/MarketplaceWeb) |
| BFF | [MarketplaceWeb.Bff](https://github.com/leandrosflora/MarketplaceWeb.Bff) |

### Microservices

| Microservice | Repositório | Responsabilidade |
|---|---|---|
| Checkout Service | [CheckoutService](https://github.com/leandrosflora/CheckoutService) | Orquestra a experiência de compra e publica solicitação de cotação/promise. |
| Product Search Service | [ProductSearchService](https://github.com/leandrosflora/ProductSearchService) | Busca produtos ofertados a partir de texto livre para alimentar o marketplace/BFF. |
| Shipping Promise Service | [ShippingPromiseService](https://github.com/leandrosflora/ShippingPromiseService) | Calcula prazo, disponibilidade, modalidade e promessa de entrega. |
| Product Catalog Service | [ProductCatalogService](https://github.com/leandrosflora/ProductCatalogService) | Fornece peso, dimensão, categoria e restrições do produto. |
| Inventory Service | [InventoryService](https://github.com/leandrosflora/InventoryService) | Consulta estoque por SKU, seller e fulfillment center. |
| Fulfillment Center Service | [FulfillmentCenterService](https://github.com/leandrosflora/FulfillmentCenterService) | Informa capacidade, cutoff, operação e disponibilidade dos CDs. |
| Routing Service | [RoutingService](https://github.com/leandrosflora/RoutingService) | Calcula rotas logísticas, malha, hubs e janelas. |
| Carrier Service | [CarrierService](https://github.com/leandrosflora/CarrierService) | Integra transportadoras, Correios, parceiros e restrições. |
| Shipping Pricing Service | [ShippingPricingService](https://github.com/leandrosflora/ShippingPricingService) | Calcula frete, custo logístico, subsídio e promoções. |
| Order Service | [OrderService](https://github.com/leandrosflora/OrderService) | Cria e mantém o pedido após confirmação da compra. |
| Shipment Service | [ShipmentService](https://github.com/leandrosflora/ShipmentService) | Cria a entrega física, etiqueta, volume, pacote e despacho. |
| Tracking Service | [TrackingService](https://github.com/leandrosflora/TrackingService) | Atualiza status de entrega, eventos de transporte e rastreio. |
| Notification Service | [NotificationService](https://github.com/leandrosflora/NotificationService) | Notifica comprador e seller sobre alterações relevantes. |

## Kafka E2E

Contratos documentados em [`docs/contracts/kafka-events.md`](docs/contracts/kafka-events.md).

Runbook local em [`docs/runbooks/kafka-local-e2e.md`](docs/runbooks/kafka-local-e2e.md).

Revisão de alinhamento em [`docs/reviews/kafka-e2e-contract-review-2026-06-14.md`](docs/reviews/kafka-e2e-contract-review-2026-06-14.md).

### Tópicos canônicos

| Tópico | Producer | Consumers | Status |
|---|---|---|---|
| `checkout.shipping.quote.requested` | `checkout-service` | `shipping-promise-service`, `audit-service`, `analytics` | Alinhado |
| `shipping.promise.calculated` | `shipping-promise-service` | `checkout-service`, `audit-service`, `analytics` | Alinhado |
| `order.created` | `order-service` | `shipment-service`, `notification-service`, `audit-service` | Alinhado |
| `shipment.created` | `shipment-service` | `tracking-service`, `notification-service`, `audit-service` | Alinhado |
| `shipment.status.updated` | `tracking-service` | `notification-service`, `audit-service`, `order-service` | Alinhado |

### Tópicos internos de saga do OrderService

Decisão documentada em [`docs/adr/0001-order-service-internal-saga-topics.md`](docs/adr/0001-order-service-internal-saga-topics.md).

| Tópico | Tipo | Finalidade |
|---|---|---|
| `inventory.commands` | Command | Reservar, confirmar ou liberar estoque durante a saga do pedido. |
| `fulfillment.commands` | Command | Validar capacidade operacional e acionar preparação logística. |
| `payment.commands` | Command | Solicitar autorização, captura ou cancelamento de pagamento. |
| `shipment.commands` | Command | Solicitar criação, cancelamento ou atualização da entrega. |
| `order.events` | Internal Event | Publicar mudanças internas do ciclo de vida do pedido. |

## Fluxos principais

### Promise assíncrona

```text
CheckoutService
  -> checkout.shipping.quote.requested
  -> ShippingPromiseService
  -> shipping.promise.calculated
  -> CheckoutService
```

### Pedido, shipment, tracking e notification

```text
OrderService
  -> order.created
  -> ShipmentService
  -> shipment.created
  -> TrackingService
  -> shipment.status.updated
  -> OrderService / NotificationService
```

## Contratos

- [`docs/contracts/README.md`](docs/contracts/README.md)
- [`docs/contracts/services-map.md`](docs/contracts/services-map.md)
- [`docs/contracts/logistica-envios-apis.openapi.yaml`](docs/contracts/logistica-envios-apis.openapi.yaml)
- [`docs/contracts/api-contract-validation.md`](docs/contracts/api-contract-validation.md)
- [`docs/contracts/kafka-events.md`](docs/contracts/kafka-events.md)

## Diagramas

### C4

- Fonte: [`docs/c4/logistica-envios-context.puml`](docs/c4/logistica-envios-context.puml)
- Imagem: [`docs/c4/logistica-envios-context.svg`](docs/c4/logistica-envios-context.svg)
- Fonte: [`docs/c4/logistica-envios-container.puml`](docs/c4/logistica-envios-container.puml)
- Imagem: [`docs/c4/logistica-envios-container.svg`](docs/c4/logistica-envios-container.svg)

### Sequence diagrams

- Fonte: [`docs/sequence-diagrams/quote-shipping.puml`](docs/sequence-diagrams/quote-shipping.puml)
- Imagem: [`docs/sequence-diagrams/quote-shipping.svg`](docs/sequence-diagrams/quote-shipping.svg)

## ADRs

- [`docs/adr/0001-use-event-driven-architecture.md`](docs/adr/0001-use-event-driven-architecture.md)
- [`docs/adr/0001-order-service-internal-saga-topics.md`](docs/adr/0001-order-service-internal-saga-topics.md)

## Runbooks e revisões

- [`docs/runbooks/kafka-local-e2e.md`](docs/runbooks/kafka-local-e2e.md)
- [`docs/reviews/kafka-e2e-validation-2026-06-14.md`](docs/reviews/kafka-e2e-validation-2026-06-14.md)
- [`docs/reviews/kafka-e2e-contract-review-2026-06-14.md`](docs/reviews/kafka-e2e-contract-review-2026-06-14.md)
- [`docs/prompts/codex-microservices-kafka-contract-fixes-2026-06-14.md`](docs/prompts/codex-microservices-kafka-contract-fixes-2026-06-14.md)

## Validação local

### Subir dependências locais

```bash
docker compose up -d
```

### Validar containers

```bash
docker compose ps
```

### Criar tópicos canônicos

```bash
docker exec -it logistica-envios-kafka kafka-topics --bootstrap-server localhost:9092 --create --if-not-exists --topic checkout.shipping.quote.requested --partitions 1 --replication-factor 1

docker exec -it logistica-envios-kafka kafka-topics --bootstrap-server localhost:9092 --create --if-not-exists --topic shipping.promise.calculated --partitions 1 --replication-factor 1

docker exec -it logistica-envios-kafka kafka-topics --bootstrap-server localhost:9092 --create --if-not-exists --topic order.created --partitions 1 --replication-factor 1

docker exec -it logistica-envios-kafka kafka-topics --bootstrap-server localhost:9092 --create --if-not-exists --topic shipment.created --partitions 1 --replication-factor 1

docker exec -it logistica-envios-kafka kafka-topics --bootstrap-server localhost:9092 --create --if-not-exists --topic shipment.status.updated --partitions 1 --replication-factor 1
```

### Criar tópicos internos de saga

```bash
docker exec -it logistica-envios-kafka kafka-topics --bootstrap-server localhost:9092 --create --if-not-exists --topic inventory.commands --partitions 1 --replication-factor 1

docker exec -it logistica-envios-kafka kafka-topics --bootstrap-server localhost:9092 --create --if-not-exists --topic fulfillment.commands --partitions 1 --replication-factor 1

docker exec -it logistica-envios-kafka kafka-topics --bootstrap-server localhost:9092 --create --if-not-exists --topic payment.commands --partitions 1 --replication-factor 1

docker exec -it logistica-envios-kafka kafka-topics --bootstrap-server localhost:9092 --create --if-not-exists --topic shipment.commands --partitions 1 --replication-factor 1

docker exec -it logistica-envios-kafka kafka-topics --bootstrap-server localhost:9092 --create --if-not-exists --topic order.events --partitions 1 --replication-factor 1
```

### Listar tópicos

```bash
docker exec -it logistica-envios-kafka kafka-topics --bootstrap-server localhost:9092 --list
```

### Kafka UI

```text
http://localhost:8088
```

## Validação de artefatos

### Validar OpenAPI/YAML

```bash
docker run --rm -v "$PWD:/work" mikefarah/yq eval docs/contracts/logistica-envios-apis.openapi.yaml
```

### Validar PlantUML

```bash
docker run --rm -v "$PWD:/work" plantuml/plantuml -checkmetadata /work/docs/c4/*.puml /work/docs/sequence-diagrams/*.puml
```

### Gerar imagens SVG dos diagramas

```bash
docker run --rm -v "$PWD:/work" plantuml/plantuml -tsvg /work/docs/c4/*.puml /work/docs/sequence-diagrams/*.puml
```

## Como usar com Codex

Ao pedir implementação, informe explicitamente:

```text
Use este repositório como fonte de contexto arquitetural.
Respeite AGENTS.md, contratos em docs/contracts, decisões em docs/adr e diagramas em docs/c4.
Não invente dependências fora dos padrões definidos.
```

Para correções de Kafka E2E, use também:

```text
Respeite o contrato canônico em docs/contracts/kafka-events.md e valide o fluxo local com docs/runbooks/kafka-local-e2e.md.
```

## DevOps

Documentação de CI/CD, qualidade, segurança e observabilidade do projeto:
- docs/devops/ci-cd.md
- docs/devops/security.md
- docs/devops/observability.md
- docs/devops/environments.md
- docs/devops/deployment.md
