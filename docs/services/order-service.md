# Order Service

## Responsabilidade

Cria e mantém o pedido após confirmação do checkout. Orquestra a saga de criação de pedido via `OrderProcessManager`, coordenando reserva de estoque, validação de fulfillment, autorização de pagamento e criação de shipment.

## Dados dominados

- **Order**: pedido confirmado com status, itens, endereço de entrega e promessa de entrega.
- **OrderSagaState**: estado corrente da saga de criação de pedido (etapa atual, compensações pendentes).

## APIs publicadas

| Método | Endpoint | Descrição |
|---|---|---|
| `POST` | `/v1/orders` | Cria um novo pedido (idempotente via `x-idempotency-key`) |
| `GET` | `/v1/orders/{orderId}` | Retorna status e dados do pedido |
| `POST` | `/v1/orders/{orderId}/cancel` | Solicita cancelamento do pedido |

## Eventos Kafka publicados

| Tópico | Quando | Schema |
|---|---|---|
| `order.created` | Pedido criado com sucesso | [kafka-events.md](../contracts/kafka-events.md#ordercreated) |
| `order.confirmed` | Saga concluída com sucesso | [kafka-events.md](../contracts/kafka-events.md#novos-eventos-canônicos) |
| `order.cancelled` | Pedido cancelado (saga falhada ou cancelamento do buyer) | [kafka-events.md](../contracts/kafka-events.md#novos-eventos-canônicos) |

## Eventos Kafka consumidos

| Tópico | Consumer Group | Finalidade |
|---|---|---|
| `checkout.confirmed` | `order-service` | Disparar criação do pedido e início da saga |
| `shipment.status.updated` | `order-service` | Atualizar status de entrega no pedido |
| `payment.approved` | `order-service` | Avançar saga após aprovação de pagamento |
| `payment.rejected` | `order-service` | Iniciar compensação da saga |

## Dependências síncronas

Nenhuma (orquestra via tópicos internos de saga Kafka).

Tópicos internos publicados pelo `OrderProcessManager`:
- `inventory.commands` → `InventoryService`
- `fulfillment.commands` → `FulfillmentCenterService`
- `payment.commands` → `PaymentService`
- `shipment.commands` → `ShipmentService`

## Persistência e infraestrutura

| Recurso | Uso |
|---|---|
| Postgres schema `order` | Persistência de `Order`, `OrderSagaState`, compensações, Outbox, Inbox e idempotência |
| Redis | Cache opcional de leitura de pedido |
| Kafka | Consumo de eventos da saga e publicação de eventos de pedido e comandos internos |

A matriz consolidada de dados fica em [data-stores.md](../contracts/data-stores.md).

## SLOs

| Métrica | Objetivo | Error Budget (30d) |
|---|---|---|
| Disponibilidade | ≥ 99.9% | 43 min/mês |
| Error rate (5xx) | < 0.1% das requisições | — |
| Latência P99 `POST /v1/orders` | < 500 ms | — |
| Latência P99 `GET /v1/orders/{id}` | < 100 ms | — |
| Tempo P95 de conclusão da saga (`checkout.confirmed` → `order.confirmed`) | < 30 s | — |
| Taxa de sagas concluídas com sucesso | ≥ 99.5% | — |

## Regras de negócio principais

1. `POST /orders` DEVE ser idempotente: mesmo `checkoutId` resulta no mesmo `orderId`.
2. O `OrderProcessManager` DEVE persistir o estado da saga em banco para suportar recovery após falha.
3. Em caso de falha em qualquer etapa da saga, as compensações DEVEM ser executadas na ordem inversa das ações bem-sucedidas.
4. Um pedido DEVE ter exatamente um `shippingPromiseId` associado, que foi previamente calculado.
5. Eventos canônicos (`order.created`, `order.confirmed`, `order.cancelled`) DEVEM ser publicados via Outbox Pattern.

## Decisões arquiteturais relacionadas

- [ADR-0007 — Tópicos internos de saga](../adr/0007-order-service-internal-saga-topics.md)
- [ADR-0002 — Saga Orchestrator](../adr/0002-saga-orchestrator-pattern.md)
- [ADR-0005 — Estratégia de Idempotência](../adr/0005-idempotency-strategy.md)
