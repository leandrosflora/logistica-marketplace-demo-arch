# Data Stores

## Objetivo

Definir ownership de persistência, schema Postgres, cache e padrões Inbox/Outbox conforme o código atual dos microservices.

## Fonte de verdade

Este arquivo foi atualizado em **2026-06-25** após varredura dos bootstraps (`Program.cs`), endpoints, repositórios e configurações Kafka dos serviços.

## Princípios

1. Cada microservice é dono exclusivo dos seus dados.
2. Em desenvolvimento local, os schemas podem rodar no mesmo Postgres do `docker-compose.yml`.
3. Nenhum microservice deve acessar tabela/schema de outro serviço diretamente.
4. Integração entre serviços ocorre por API REST ou Kafka.
5. Outbox/Inbox só deve ser documentado como implementado quando existir no código/registration atual.

## Matriz de dados implementada

| Serviço | Schema/Banco atual | Dados dominados | Cache | Kafka persistence pattern observado |
|---|---|---|---|---|
| Marketplace BFF | Sem banco próprio nesta documentação | Agregação transiente da experiência web | Opcional | Não aplicável neste repo de arquitetura |
| Product Search Service | Connection string `Default`; read model em tabela `products` | Índice/read model de produtos ativos para busca | Não registrado no bootstrap atual | Não usa Kafka diretamente no código atual |
| Checkout Service | `CheckoutDb`; fallback para mocks se sem connection string | Checkout, itens, idempotência, projeção de promise | Não registrado como Redis no bootstrap atual | Publica `checkout.shipping.quote.requested` e `checkout.confirmed`; consome `shipping.promise.calculated` quando Kafka configurado |
| Shipping Promise Service | `ShippingPromiseDb` | Promessas calculadas e auditoria/snapshot da composição | Redis com prefixo `shipping-promise:` | Consome `checkout.shipping.quote.requested`; publica `shipping.promise.calculated` |
| Product Catalog Service | `product_catalog` via `ProductCatalogDbConnectionFactory` | Atributos logísticos de SKU, peso, dimensões e restrições | Redis | Possui outbox writer; não há dispatcher Kafka registrado no `Program.cs` atual |
| Inventory Service | `InventoryDb` | Saldos e reservas de estoque | Não registrado no bootstrap atual | Consome `inventory.commands`; publica `inventory.reserved`, `inventory.reservation.confirmed`, `inventory.reservation.failed`, `inventory.reservation.released` |
| Fulfillment Center Service | `FulfillmentDb` | Centros, capacidade, calendário operacional e reservas | Não registrado no bootstrap atual | Consome `fulfillment.commands`; publica `fulfillment.capacity.reserved`, `fulfillment.capacity.confirmed`, `fulfillment.capacity.failed` |
| Routing Service | `RoutingDb`; pode usar mock repository | Grafo logístico, lanes e rotas calculadas | Redis com prefixo `routing:` ou distributed memory cache em modo mock | Não usa Kafka no bootstrap atual |
| Carrier Service | `CarrierDb` | Carriers, service levels, lanes, status e disponibilidade | Redis com prefixo `carrier:` | Possui outbox writer administrativo; não há dispatcher Kafka registrado no `Program.cs` atual |
| Shipping Pricing Service | `PricingDb` | Rate cards, políticas, preços e quotes | Redis com prefixo `shipping-pricing:` | Possui outbox writer; não há dispatcher Kafka registrado no `Program.cs` atual |
| Payment Service | Schema Postgres `payment` (search_path) | `PaymentAuthorization`, inbox e outbox | Não registrado no bootstrap atual | Consome `payment.commands`; publica `payment.approved`, `payment.rejected`, `payment.captured`, `payment.capture.failed` |
| Order Service | `OrderDb`; schema default `order_domain` no fallback | Orders, itens, inbox, outbox, estado da saga e idempotência | Não registrado no bootstrap atual | Consome `checkout.confirmed`, eventos de inventory/fulfillment/payment/shipment/status; publica `order.created`, `inventory.commands`, `fulfillment.commands`, `payment.commands`, `shipment.commands`, `order.events` |
| Shipment Service | `ShipmentDb` | Shipment, packages, itens, etiqueta, inbox/outbox | FileSystem para labels; cache não registrado | Consome `order.created` e `shipment.commands`; publica `shipment.created`; escreve `carrier-shipment.commands` em cancelamento |
| Tracking Service | `TrackingDb` | ShipmentTracking e TrackingEvent | Não registrado no bootstrap atual | Consome `shipment.created`; publica `shipment.status.updated` |
| Notification Service | `NotificationDb` | Notifications, deliveries, preferences, outbox/inbox | Não registrado no bootstrap atual | Consome eventos configurados em `KafkaOptions`; publica via canais externos Email/SMS/Push, não eventos canônicos |
| Audit Service | Schema Postgres `audit` (search_path); acesso via Dapper/Npgsql, não EF Core | `AuditEntry` (imutável), inbox | Não registrado no bootstrap atual | Consome os dez tópicos canônicos com producer real; não publica eventos |

## Infraestrutura local

O `docker-compose.yml` deste repo fornece infraestrutura compartilhada para desenvolvimento/demo:

| Recurso | Uso local |
|---|---|
| Postgres `logistica_envios` | Banco compartilhado local com schemas por domínio quando aplicável |
| Redis | Cache local para serviços que registram Redis no bootstrap |
| Kafka | Broker local para eventos e comandos efetivamente configurados |
| Kafka UI | Inspeção manual dos tópicos |
| Prometheus/Grafana | Observabilidade local |

## Convenções de schema

| Tipo | Convenção |
|---|---|
| Schema Postgres | `snake_case` por domínio quando o serviço usa schema explícito |
| Outbox | Tabela de outbox por serviço produtor quando implementada |
| Inbox | Tabela de inbox por serviço consumidor quando implementada |
| Idempotência | Persistida no domínio quando exposta em API ou comando crítico |
| Redis key prefix | Prefixo definido no bootstrap do serviço quando registrado |

## Observações

- `ProductSearchService` não deve ser documentado como OpenSearch em produção atual: o código registra `PostgresProductSearchRepository`.
- `AuditService` usa Dapper/Npgsql em vez de EF Core — escolha arquitetural explícita, não inconsistência a corrigir.
- Tópicos sem producer implementado devem ser marcados como configurados/pendentes, não como fluxo E2E pronto.
