# Data Stores

## Objetivo

Definir ownership de persistencia, schema Postgres, uso de cache e padroes Inbox/Outbox por microservice. Este arquivo e a referencia canonica para bancos de dados e caches do case Logistica Envios.

## Principios

1. Cada microservice e dono exclusivo dos seus dados.
2. Em desenvolvimento local, todos os schemas podem rodar no mesmo Postgres do `docker-compose.yml`.
3. Em ambientes gerenciados, os schemas podem continuar no mesmo RDS ou serem segregados por instancia conforme volume, criticidade e custo.
4. Nenhum microservice acessa tabela/schema de outro servico diretamente.
5. Integracao entre servicos ocorre por API REST ou Kafka.
6. Servicos que publicam eventos canonicos usam Outbox Pattern.
7. Servicos que consomem eventos ou comandos Kafka usam Inbox Pattern.

## Matriz de dados

| Servico | Schema/Banco canonico | Dados dominados | Redis/cache | Kafka persistence pattern |
|---|---|---|---|---|
| Marketplace BFF | Sem banco proprio | Agregacao transiente da experiencia web | Cache opcional de composicao de pagina | Nao aplicavel |
| Product Search Service | `product_search` | Indice materializado de produtos ofertados | Cache de consultas frequentes e facetas | Inbox apenas se o indice for alimentado por eventos de catalogo fora do escopo |
| Checkout Service | `checkout` | Checkout, itens selecionados, ShippingPromiseProjection, idempotencia | Cache curto de promise e sessao de checkout | Outbox para `checkout.shipping.quote.requested` e `checkout.confirmed`; Inbox para `shipping.promise.calculated` |
| Shipping Promise Service | `shipping_promise` | ShippingPromise calculada, snapshots de composicao da promessa | Cache de promise, rota, catalogo e pricing | Outbox para `shipping.promise.calculated`; Inbox para `checkout.shipping.quote.requested` |
| Product Catalog Service | `product_catalog` | Atributos logisticos de SKU, dimensoes, peso e restricoes | Cache de atributos logisticos por SKU | Nao aplicavel no escopo atual |
| Inventory Service | `inventory` | InventoryBalance e InventoryReservation | Cache opcional de disponibilidade por SKU/seller/FC | Inbox para `inventory.commands` |
| Fulfillment Center Service | `fulfillment` | FulfillmentCenter, CapacityWindow e reservas de capacidade | Cache opcional de capacidade/cutoff | Inbox para `fulfillment.commands` |
| Routing Service | `routing` | LogisticNetwork, lanes, hubs, rotas calculadas | Cache de rotas e SLA | Nao aplicavel no escopo atual |
| Carrier Service | `carrier` | CarrierOption, CarrierRestriction, disponibilidade e integracoes externas | Cache de disponibilidade e restricoes de transportadora | Nao aplicavel no escopo atual |
| Shipping Pricing Service | `shipping_pricing` | FreightPrice, RateCard, SubsidyRule e promocoes | Cache de regras de subsidio e rate cards | Nao aplicavel no escopo atual |
| Order Service | `order` | Order, OrderSagaState, compensacoes, idempotencia | Cache opcional de leitura de pedido | Outbox para `order.created`, `order.confirmed`, `order.cancelled` e comandos internos; Inbox para `checkout.confirmed`, `shipment.status.updated`, `payment.approved`, `payment.rejected` |
| Payment Service | `payment` | PaymentAuthorization, PaymentTransaction e compensacoes | Cache curto de idempotencia e retry | Outbox para `payment.approved` e `payment.rejected`; Inbox para `payment.commands` |
| Shipment Service | `shipment` | Shipment, ShipmentVolume, etiqueta e codigo de rastreio | Cache opcional de etiqueta temporaria/status | Outbox para `shipment.created` e `shipment.cancelled`; Inbox para `order.created`, `order.cancelled`, `shipment.commands` |
| Tracking Service | `tracking` | TrackingTimeline e TrackingStatus | Cache opcional de consulta publica por trackingCode | Outbox para `shipment.status.updated`; Inbox para `shipment.created` |
| Notification Service | `notification` | NotificationPlan, NotificationLog e preferencias materializadas | Cache opcional de preferencias/canais | Inbox para eventos de pedido, pagamento e shipment |
| Audit Service | `audit` | AuditEntry imutavel | Sem cache por padrao | Inbox para todos os eventos canonicos auditaveis |

## Infraestrutura local

O `docker-compose.yml` fornece:

| Recurso | Uso local |
|---|---|
| Postgres `logistica_envios` | Banco compartilhado local com um schema por microservice |
| Redis | Cache local compartilhado, com prefixo de chave por servico |
| Kafka | Broker local para eventos canonicos e comandos internos de saga |

## Convencoes de schema

| Tipo | Convencao |
|---|---|
| Schema Postgres | `snake_case` com nome do dominio (`checkout`, `order`, `shipment`) |
| Tabelas de dominio | Nome no plural quando representar colecao persistida |
| Outbox | `<schema>.outbox_messages` |
| Inbox | `<schema>.inbox_messages` |
| Idempotencia | `<schema>.idempotency_keys` quando exposta via API ou comando critico |
| Redis key prefix | `<service-name>:<context>:<id>` |

## Observacoes

- O uso de um Postgres unico e aceitavel para desenvolvimento local e demo, desde que o isolamento por schema seja respeitado.
- Em producao, a decisao entre schema compartilhado, banco dedicado ou cluster dedicado deve considerar volume, criticidade, isolamento regulatorio e custo operacional.
- `Payment Service` e tratado como microservice interno do case; provedores de pagamento externos sao dependencias sincronas dele, nao donos da saga.
