# Order Visibility Service

## Responsabilidade

Consome os eventos canônicos da jornada do pedido (checkout → order → inventory/fulfillment → payment → shipment/tracking) e mantém um read model materializado ("status consolidado" + timeline) para consulta operacional em tempo real via API REST e SignalR. Alimenta a tela "Order Monitor" em `MarketplaceWeb` (`/operations/orders`).

**Não é** o dono transacional de nenhum dado de negócio, **não** orquestra a saga, **não** publica comandos e **não** executa compensação — quem faz isso é o `OrderService`. Uma indisponibilidade deste serviço não afeta o processamento da saga em nenhum outro serviço (ver design.md em `openspec/changes/order-visibility-realtime/`).

## Dados dominados

- **OrderJourney**: estado consolidado de uma jornada de pedido — `orderId`/`checkoutId`/`buyerId`/`sellerId` (todos nullable até chegarem no payload), `currentStatus`, `lastEventAt`, `correlationId`, `rootTraceId`, `hasError`/`errorReason`.
- **OrderJourneyEvent**: timeline detalhada — um registro por evento consumido, com `topic`, `partition`, `offsetValue`, `serviceName` (producer), `statusBefore`/`statusAfter`, `traceId`/`spanId` (quando presentes) e o payload completo (`payload_json`).

A identidade da jornada é resolvida por `orderId` → `checkoutId` → `correlationId`, nessa ordem, porque a jornada começa antes de existir um `orderId` (na confirmação do checkout).

## APIs publicadas

| Método | Endpoint | Descrição |
|---|---|---|
| `GET` | `/order-journeys` | Lista jornadas com filtros (`status`, `hasError`, `buyerId`, `sellerId`, `orderId`, `checkoutId`, `correlationId`, `updatedAfter`, `updatedBefore`) e paginação (`page`, `pageSize`) |
| `GET` | `/order-journeys/stuck?olderThanSeconds=N` | Jornadas sem erro, não terminais, sem evento há mais de N segundos |
| `GET` | `/order-journeys/{orderId}` | Jornada por `orderId` |
| `GET` | `/order-journeys/by-checkout/{checkoutId}` | Jornada por `checkoutId` |
| `GET` | `/order-journeys/by-correlation/{correlationId}` | Jornada por `correlationId` (única forma de consulta antes de existir `orderId`) |
| `GET` | `/order-journeys/{orderId}/events` | Timeline completa de uma jornada |
| `GET` | `/health` | Health check (inclui conectividade com Postgres) |
| `GET` | `/metrics` | Métricas Prometheus |

`correlationId` é uma **string opaca**, não um GUID: alguns produtores (ex. `CheckoutService`) usam `HttpContext.TraceIdentifier` (formato `"0HNMNNLB70E9S:00000043"`) como fallback quando o chamador não envia `X-Correlation-Id`. Clientes devem URL-encodar o valor ao montar a rota `by-correlation/{correlationId}`.

## Eventos Kafka publicados

Nenhum. O serviço só consome; atualizações em tempo real são entregues via SignalR (`/order-journeys/hub`), não via Kafka.

## Eventos Kafka consumidos

| Tópico | Consumer Group | Finalidade |
|---|---|---|
| `checkout.confirmed` | `order-visibility-service` | Início da jornada (`CheckoutConfirmed`) |
| `order.created` | idem | Backfill de `orderId` na jornada existente (`OrderCreated`) |
| `inventory.reserved`, `inventory.reservation.confirmed` | idem | `InventoryReserved` |
| `inventory.reservation.failed` | idem | `InventoryFailed`, `hasError=true` |
| `fulfillment.capacity.reserved`, `fulfillment.capacity.confirmed` | idem | `FulfillmentReserved` |
| `fulfillment.capacity.failed` | idem | `FulfillmentFailed`, `hasError=true` |
| `payment.approved` | idem | `PaymentAuthorized` |
| `payment.rejected` | idem | `PaymentRejected`, `hasError=true` |
| `payment.captured` | idem | `PaymentCaptured` |
| `payment.capture.failed` | idem | `PaymentCaptureFailed`, `hasError=true` |
| `shipment.created` | idem | `ShipmentCreated` |
| `shipment.status.updated` | idem | `InTransit`/`Delivered`/`Failed` conforme `currentStatus` do payload |

Nenhum tópico `*.commands` é consumido: comando representa intenção, não fato ocorrido, e não deve alimentar status de negócio (ver `docs/contracts/kafka-events.md`).

## Dependências síncronas

Nenhuma dependência síncrona de outro serviço. `MarketplaceWeb` chama este serviço via HTTP para renderizar a tela `/operations/orders`.

## Persistência e infraestrutura

| Recurso | Uso |
|---|---|
| Postgres schema `order_visibility` | `order_journey`, `order_journey_events` (ver `database/logistica-envios-init.sql`) |
| Redis | Não utilizado |
| Kafka | Apenas consumo, ~12 tópicos, um único consumer group |
| SignalR | Hub `/order-journeys/hub`, grupos `orders:all`, `orders:{orderId}`, `correlation:{correlationId}`, `status:{status}` |

A matriz consolidada de dados fica em [data-stores.md](../contracts/data-stores.md).

## SLOs sugeridos

| Métrica | Objetivo |
|---|---|
| Disponibilidade | ≥ 99% (não crítico para o fluxo de compra) |
| Lag de consumo (`order_journey_consumer_lag`) | < 500 mensagens |
| Latência P99 `GET /order-journeys/{orderId}` | < 200 ms |
| Detecção de pedido travado | ≤ `StuckJourney:PollIntervalSeconds` (padrão 15s) após cruzar o limiar |

## Regras de negócio principais

1. Idempotência por `eventId`: evento já presente em `order_journey_events` é ignorado (constraint `UNIQUE (event_id)`).
2. Insert da timeline e update do status ocorrem na mesma transação Postgres.
3. Eventos fora de ordem são sempre gravados na timeline, mas só avançam `current_status`/`last_event_at` quando `occurredAt` não é anterior ao `last_event_at` atual da jornada.
4. Eventos sem `eventId` ou `correlationId` válidos são descartados ("quarantined") com log de `Warning`, não travam o consumer.
5. "Travado" é sempre calculado em tempo de consulta (`has_error = false` AND status não-terminal AND `last_event_at` mais antigo que o limiar) — nunca persistido como status.
6. Métricas Prometheus nunca usam `orderId`, `checkoutId` ou `correlationId` como label (alta cardinalidade); labels permitidos: `status`, `event_type`, `topic`, `service`, `error_reason`.

## Limitações conhecidas

- `order_journey_consumer_lag` é agregado entre todas as partitions assinadas, não quebrado por tópico.
- `order_journey_step_duration_seconds` mede um único salto (status atual → próximo evento), não o caminho completo entre dois eventos não-adjacentes.
- `traceId`/`spanId` no envelope hoje só são populados por `CheckoutService` e `FulfillmentCenterService`; os demais produtores caem no fallback de busca por `correlationId` no Jaeger (ver tabela de adoção em `docs/contracts/kafka-events.md`).
- O cliente realtime do Order Monitor usa polling (a cada ~4s) em vez do hub SignalR — o hub está implementado e pronto, mas o cliente JS não foi conectado nesta mudança (ver `docs/runbooks/order-visibility-local.md`).

## Decisões arquiteturais relacionadas

Ver `openspec/changes/order-visibility-realtime/design.md` (proposta, design e specs completos desta mudança).
