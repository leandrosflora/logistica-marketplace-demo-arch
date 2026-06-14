# Meli Envios Architecture

Repositório de arquitetura para estudo do case **Meli Envios**.

Objetivo: dar contexto suficiente para o Codex entender o domínio, os microservices, os contratos, os eventos Kafka, os diagramas C4, as decisões arquiteturais e os comandos de validação local.

## Estrutura

```text
meli-envios-architecture
├── docs/
│   ├── c4/
│   ├── sequence-diagrams/
│   ├── contracts/
│   └── adr/
├── docker-compose.yml
├── README.md
└── AGENTS.md
```

## Domínio

Este case modela uma plataforma de cálculo de frete, promessa de entrega, disponibilidade logística e criação de shipment para milhões de pedidos por dia.

## Repositórios envolvidos

### Canal e BFF

| Componente | Repositório |
|---|---|
| Frontend | [MarketplaceWeb](https://github.com/leandrosflora/MarketplaceWeb) |
| BFF | [MarketplaceWeb.Bff](https://github.com/leandrosflora/MarketplaceWeb.Bff) |

### Microservices

| Microservice | Repositório |
|---|---|
| Checkout Service | [CheckoutService](https://github.com/leandrosflora/CheckoutService) |
| Product Catalog Service | [ProductCatalogService](https://github.com/leandrosflora/ProductCatalogService) |
| Product Search Service | [ProductSearchService](https://github.com/leandrosflora/ProductSearchService) |
| Shipping Promise Service | [ShippingPromiseService](https://github.com/leandrosflora/ShippingPromiseService) |
| Notification Service | [NotificationService](https://github.com/leandrosflora/NotificationService) |
| Shipment Service | [ShipmentService](https://github.com/leandrosflora/ShipmentService) |
| Carrier Service | [CarrierService](https://github.com/leandrosflora/CarrierService) |
| Inventory Service | [InventoryService](https://github.com/leandrosflora/InventoryService) |
| Routing Service | [RoutingService](https://github.com/leandrosflora/RoutingService) |
| Shipping Pricing Service | [ShippingPricingService](https://github.com/leandrosflora/ShippingPricingService) |
| Order Service | [OrderService](https://github.com/leandrosflora/OrderService) |
| Tracking Service | [TrackingService](https://github.com/leandrosflora/TrackingService) |
| Fulfillment Center Service | [FulfillmentCenterService](https://github.com/leandrosflora/FulfillmentCenterService) |

## Microservices principais

| Serviço | Responsabilidade |
|---|---|
| Checkout Service | Orquestra a experiência de compra e chama a cotação de envio. |
| Product Search Service | Busca produtos ofertados a partir de texto livre para alimentar o marketplace/BFF. |
| Shipping Promise Service | Calcula prazo, disponibilidade, modalidade e promessa de entrega. |
| Product Catalog Service | Fornece peso, dimensão, categoria e restrições do produto. |
| Inventory Service | Consulta estoque por SKU, seller e fulfillment center. |
| Fulfillment Center Service | Informa capacidade, cutoff, operação e disponibilidade dos CDs. |
| Routing Service | Calcula rotas logísticas, malha, hubs e janelas. |
| Carrier Service | Integra transportadoras, Correios, parceiros e restrições. |
| Shipping Pricing Service | Calcula frete, custo logístico, subsídio e promoções. |
| Order Service | Cria e mantém o pedido após confirmação da compra. |
| Shipment Service | Cria a entrega física, etiqueta, volume e pacote. |
| Tracking Service | Atualiza status de entrega e eventos de rastreio. |
| Notification Service | Notifica comprador e seller sobre alterações relevantes. |
| Audit Service | Mantém rastreabilidade técnica, funcional e regulatória. |

## Eventos Kafka

Eventos documentados em [`docs/contracts/kafka-events.md`](docs/contracts/kafka-events.md).

Principais tópicos:

- `checkout.shipping.quote.requested`
- `shipping.promise.calculated`
- `order.created`
- `shipment.created`
- `shipment.status.updated`
- `shipment.delivery.failed`
- `shipment.delivery.completed`

## Contratos

- [`docs/contracts/README.md`](docs/contracts/README.md)
- [`docs/contracts/services-map.md`](docs/contracts/services-map.md)
- [`docs/contracts/meli-envios-apis.openapi.yaml`](docs/contracts/meli-envios-apis.openapi.yaml)
- [`docs/contracts/api-contract-validation.md`](docs/contracts/api-contract-validation.md)
- [`docs/contracts/kafka-events.md`](docs/contracts/kafka-events.md)

## Diagramas

### C4

- Fonte: [`docs/c4/meli-envios-context.puml`](docs/c4/meli-envios-context.puml)
- Imagem: [`docs/c4/meli-envios-context.svg`](docs/c4/meli-envios-context.svg)
- Fonte: [`docs/c4/meli-envios-container.puml`](docs/c4/meli-envios-container.puml)
- Imagem: [`docs/c4/meli-envios-container.svg`](docs/c4/meli-envios-container.svg)

### Sequence diagrams

- Fonte: [`docs/sequence-diagrams/quote-shipping.puml`](docs/sequence-diagrams/quote-shipping.puml)
- Imagem: [`docs/sequence-diagrams/quote-shipping.svg`](docs/sequence-diagrams/quote-shipping.svg)

## ADRs

- [`docs/adr/0001-use-event-driven-architecture.md`](docs/adr/0001-use-event-driven-architecture.md)

## Validação local

Subir dependências locais:

```bash
docker compose up -d
```

Validar arquivos YAML:

```bash
docker run --rm -v "$PWD:/work" mikefarah/yq eval docs/contracts/meli-envios-apis.openapi.yaml
```

Validar PlantUML:

```bash
docker run --rm -v "$PWD:/work" plantuml/plantuml -checkmetadata /work/docs/c4/*.puml /work/docs/sequence-diagrams/*.puml
```

Gerar imagens SVG dos diagramas:

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
