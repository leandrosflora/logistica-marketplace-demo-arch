# Mapa de Microservices

## Fonte de verdade

Este mapa reflete a varredura dos repositórios de código dos microservices em **2026-06-25**.

Foram considerados os serviços efetivamente existentes como repositórios próprios e os endpoints, consumers, producers, bancos e caches registrados no código.

## Microservices implementados

| Serviço | Repo | Tipo | Entrada principal | Saída principal | Observação de implementação |
|---|---|---|---|---|---|
| Product Search Service | `ProductSearchService` | Leitura/search | `GET /v1/products/search` | cards de produto paginados | Usa read model em Postgres via Dapper/Npgsql. OpenSearch é evolução/planejado, não o runtime atual. |
| Checkout Service | `CheckoutService` | Jornada | `POST /v1/checkouts`, `POST /v1/checkouts/{id}/confirm` | `checkout.shipping.quote.requested`, `checkout.confirmed` | Suporta modo mock quando `CheckoutDb` não está configurado; consome `shipping.promise.calculated` quando Kafka está configurado. |
| Shipping Promise Service | `ShippingPromiseService` | Domínio logístico | `POST /v1/shipping-promises`, `checkout.shipping.quote.requested` | `shipping.promise.calculated` | Consulta Catalog, Inventory, Fulfillment, Routing, Carrier e Pricing por HTTP; usa Postgres e Redis. |
| Product Catalog Service | `ProductCatalogService` | Domínio catálogo | `GET /v1/products/{skuId}/logistics`, `GET /v1/products/logistics/batch` | atributos logísticos de SKU | Usa Postgres e Redis. Possui outbox local, mas não há dispatcher Kafka registrado no bootstrap atual. |
| Inventory Service | `InventoryService` | Domínio estoque | APIs de disponibilidade/reserva e `inventory.commands` | `inventory.reserved`, `inventory.reservation.confirmed`, `inventory.reservation.failed`, `inventory.reservation.released` | Usa Postgres, consumer de comandos e outbox dispatcher. |
| Fulfillment Center Service | `FulfillmentCenterService` | Domínio fulfillment | APIs de CD/capacidade e `fulfillment.commands` | `fulfillment.capacity.reserved`, `fulfillment.capacity.confirmed`, `fulfillment.capacity.failed` | Usa Postgres, consumer de comandos e outbox dispatcher. |
| Routing Service | `RoutingService` | Domínio roteirização | `POST /v1/routes/calculate`, `GET /v1/routes/{routeId}` | rota calculada e SLA | Usa Postgres/Redis ou mock repository conforme configuração. Não usa Kafka no bootstrap atual. |
| Carrier Service | `CarrierService` | Integração logística | `/v1/carrier-availability/search`, `/v1/carriers/*` | disponibilidade, perfis e regras de carrier | Usa Postgres, Redis e adapters HTTP externos. Possui outbox local para eventos administrativos, sem dispatcher Kafka registrado. |
| Shipping Pricing Service | `ShippingPricingService` | Domínio precificação | `/v1/pricing/freight`, `/shipping-prices/quotes/*`, `/rate-cards/*` | preço de frete, quote e rate cards | Usa Postgres, Redis e engine local de pricing. Possui outbox local, sem dispatcher Kafka registrado. |
| Order Service | `OrderService` | Domínio pedido/saga | `checkout.confirmed`, APIs `/orders/*` | `order.created`, `inventory.commands`, `fulfillment.commands`, `payment.commands`, `shipment.commands`, `order.events` | Orquestra a saga por outbox. `payment.commands` existe no código, mas não há `PaymentService` implementado no conjunto atual. |
| Shipment Service | `ShipmentService` | Domínio entrega | `order.created`, `shipment.commands`, APIs `/shipments/*` | `shipment.created`, `carrier-shipment.commands` | Cria shipment, pacote, etiqueta e aciona integração com carrier. Não publica `shipment.cancelled` no KafkaOptions atual. |
| Tracking Service | `TrackingService` | Domínio tracking | `shipment.created`, `POST /v1/tracking/events` | `shipment.status.updated` | Mantém timeline de tracking e publica atualização de status via outbox dispatcher. |
| Notification Service | `NotificationService` | Plataforma de notificação | eventos Kafka e APIs `/v1/notifications/*`, `/v1/notification-preferences/*`, `/v1/providers/*/receipts` | envio Email/SMS/Push e persistência de entregas | Consome eventos configurados; alguns produtores esperados ainda não existem no código atual. |

## Componentes não implementados como microservice

| Componente | Situação real no código | Como documentar/validar |
|---|---|---|
| Payment Service | Não existe repositório `leandrosflora/PaymentService`. Porém o `OrderService` escreve `payment.commands` e possui handlers internos para eventos de pagamento. | Tratar como dependência externa/simulada da saga até existir implementação própria. Não documentar como microservice implementado. |
| Audit Service | Não existe repositório `leandrosflora/AuditService`. | Não documentar como microservice implementado. Auditoria pode ser evolução futura ou concern transversal de observabilidade/logs. |

## Fluxo síncrono de cotação

1. Frontend chama BFF.
2. BFF chama `ProductSearchService` para descoberta de produtos.
3. Checkout ou BFF chama `ShippingPromiseService` para cotação.
4. `ShippingPromiseService` consulta por HTTP:
   - `ProductCatalogService`;
   - `InventoryService`;
   - `FulfillmentCenterService`;
   - `RoutingService`;
   - `CarrierService`;
   - `ShippingPricingService`.
5. Resultado volta com disponibilidade, prazo, modalidade, carrier e preço.

## Fluxo assíncrono implementado

1. `CheckoutService` publica `checkout.shipping.quote.requested`.
2. `ShippingPromiseService` consome e publica `shipping.promise.calculated`.
3. `CheckoutService` consome a promise calculada e pode confirmar o checkout.
4. `CheckoutService` publica `checkout.confirmed`.
5. `OrderService` consome `checkout.confirmed`, cria `Order` e publica:
   - `order.created`;
   - `inventory.commands`;
   - `fulfillment.commands`.
6. `InventoryService` e `FulfillmentCenterService` consomem comandos e publicam eventos de reserva/confirmação/falha.
7. Quando estoque e capacidade estão reservados, `OrderService` escreve `payment.commands`.
8. Como `PaymentService` não está implementado, essa etapa deve ser simulada ou tratada como integração externa pendente.
9. Após eventos internos de pagamento/captura, `OrderService` escreve `shipment.commands` e `order.events`.
10. `ShipmentService` consome `order.created` e/ou `shipment.commands`, cria shipment e publica `shipment.created`.
11. `TrackingService` consome `shipment.created` e publica `shipment.status.updated` ao receber eventos de tracking.
12. `NotificationService` consome eventos configurados e planeja/envia notificações.

## Dados e infraestrutura

A matriz de bancos, schemas, caches e padrões Inbox/Outbox fica em [`data-stores.md`](data-stores.md).

## Detalhe da varredura

Relatório de alinhamento: [`../reviews/microservices-code-alignment-2026-06-25.md`](../reviews/microservices-code-alignment-2026-06-25.md).
