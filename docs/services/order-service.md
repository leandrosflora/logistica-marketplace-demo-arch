# Order Service

## Responsabilidade real no código

Mantém pedidos criados a partir de `checkout.confirmed` e orquestra a saga de pedido por Kafka/outbox.

No estado atual, o serviço:

- consome confirmação de checkout;
- cria `Order`;
- publica `order.created`;
- envia comandos para estoque e fulfillment;
- envia `payment.commands` quando estoque e capacidade estão reservados;
- envia `shipment.commands` quando a saga avança para criação de shipment;
- atualiza pedido com eventos de shipment/tracking;
- expõe consulta e cancelamento de pedido por HTTP.

## Dados dominados

- **Order**: pedido com checkout, buyer, seller, itens, status, valores, reservas, pagamento e shipment associados.
- **OrderItem**: itens do pedido.
- **InboxMessage**: controle de idempotência de mensagens consumidas.
- **OutboxMessage**: mensagens produzidas para Kafka.

## APIs publicadas

| Método | Endpoint | Descrição |
|---|---|---|
| `GET` | `/orders/{orderId}` | Retorna status e dados do pedido |
| `POST` | `/orders/{orderId}/cancel` | Solicita cancelamento do pedido; exige header `Idempotency-Key` |
| `GET` | `/health` | Health check |

Não há endpoint `POST /v1/orders` implementado no código atual. A criação do pedido ocorre por consumo de `checkout.confirmed`.

## Eventos e comandos publicados

| Tópico | Quando | Status prático |
|---|---|---|
| `order.created` | Ao consumir `checkout.confirmed` e criar o pedido | Implementado |
| `inventory.commands` | Para reservar, confirmar ou liberar reserva de estoque | Implementado |
| `fulfillment.commands` | Para reservar, confirmar ou liberar capacidade de fulfillment | Implementado |
| `payment.commands` | Para autorizar, capturar ou cancelar autorização de pagamento | Implementado; consumido por `PaymentService` |
| `shipment.commands` | Para solicitar criação de shipment | Implementado |
| `order.events` | Para eventos internos de confirmação/cancelamento | Interno; não equivale hoje a `order.confirmed`/`order.cancelled` canônicos |

## Eventos Kafka consumidos registrados no bootstrap

| Tópico | Consumer/handler registrado | Finalidade |
|---|---|---|
| `checkout.confirmed` | `CheckoutConfirmedConsumer` | Criar pedido e iniciar saga |
| `inventory.reserved` | `InventoryReservedConsumer` | Marcar estoque reservado e avaliar avanço da saga |
| `inventory.reservation.failed` | `InventoryReservationFailedConsumer` | Cancelar/compensar saga |
| `fulfillment.capacity.reserved` | `FulfillmentCapacityReservedConsumer` | Marcar capacidade reservada e avaliar avanço da saga |
| `fulfillment.capacity.failed` | `FulfillmentCapacityFailedConsumer` | Cancelar/compensar saga |
| `shipment.created` | `ShipmentCreatedConsumer` | Associar shipment ao pedido e disparar captura de pagamento |
| `shipment.status.updated` | `ShipmentStatusUpdatedConsumer` | Atualizar status de entrega no pedido |
| `payment.approved` | `PaymentResponseConsumer` | Marcar pagamento autorizado e avaliar avanço da saga |
| `payment.rejected` | `PaymentResponseConsumer` | Cancelar/compensar saga por recusa de autorização |
| `payment.captured` | `PaymentResponseConsumer` | Marcar pagamento capturado |
| `payment.capture.failed` | `PaymentResponseConsumer` | Registrar falha de captura |

## Tópicos declarados em configuração, mas sem hosted consumer localizado

| Tópico | Observação |
|---|---|
| `inventory.reservation.confirmed` | Existe em `KafkaOptions`; handler interno existe, mas consumer registrado no `Program.cs` não foi localizado. |
| `fulfillment.capacity.confirmed` | Existe em `KafkaOptions`; handler interno existe, mas consumer registrado no `Program.cs` não foi localizado. |
| `shipment.creation.failed` | Existe em `KafkaOptions`; consumer registrado no `Program.cs` não foi localizado. |

## Dependências síncronas

Nenhuma dependência HTTP síncrona registrada. A integração ocorre via Kafka/outbox.

## Persistência e infraestrutura

| Recurso | Uso |
|---|---|
| Postgres `OrderDb` | Persistência de pedidos, itens, inbox e outbox |
| Schema fallback | `order_domain` no fallback de connection string |
| Kafka | Consumo de eventos da saga e publicação de eventos/comandos |
| Redis | Não registrado no bootstrap atual |
| OpenTelemetry | Tracing, metrics e exporter OTLP |

A matriz consolidada de dados fica em [data-stores.md](../contracts/data-stores.md).

## SLOs sugeridos

| Métrica | Objetivo |
|---|---|
| Disponibilidade | ≥ 99.9% |
| Error rate 5xx | < 0.1% |
| Latência P99 `GET /orders/{id}` | < 100 ms |
| Latência P99 `POST /orders/{id}/cancel` | < 500 ms |

## Regras de negócio principais

1. Pedido nasce a partir de `checkout.confirmed`; não por API pública de criação.
2. Processamento de mensagens usa inbox para evitar duplicidade.
3. Publicação usa outbox para garantir entrega eventual.
4. Estoque e capacidade são reservados antes da etapa de pagamento.
5. Pagamento é autorizado/capturado por `PaymentService`, consumido via `payment.approved`/`payment.rejected`/`payment.captured`/`payment.capture.failed`.
6. `order.events` é tópico interno/controlado, não deve ser vendido como tópico canônico público sem ajuste no código.

## Decisões arquiteturais relacionadas

- [ADR-0007 — Tópicos internos de saga](../adr/0007-order-service-internal-saga-topics.md)
- [ADR-0002 — Saga Orchestrator](../adr/0002-saga-orchestrator-pattern.md)
- [ADR-0005 — Estratégia de Idempotência](../adr/0005-idempotency-strategy.md)
