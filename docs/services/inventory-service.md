# Inventory Service

## Responsabilidade

Gerencia saldo e reservas de estoque por SKU, seller e fulfillment center. Responde a consultas de disponibilidade durante a cotação de frete e executa reservas/liberações durante a saga de criação de pedido.

## Dados dominados

- **InventoryBalance**: saldo disponível por SKU/seller/FC.
- **InventoryReservation**: reserva temporária de estoque associada a um pedido em andamento.

## APIs publicadas

| Método | Endpoint | Descrição |
|---|---|---|
| `GET` | `/v1/inventory/{skuId}/availability` | Consulta disponibilidade por SKU/seller/FC |
| `POST` | `/v1/inventory/reservations` | Cria reserva de estoque (comando idempotente) |
| `DELETE` | `/v1/inventory/reservations/{reservationId}` | Libera reserva (compensação de saga) |
| `POST` | `/v1/inventory/reservations/{reservationId}/confirm` | Confirma reserva (estoque efetivamente baixado) |

## Eventos Kafka publicados

Nenhum canônico neste momento. Responde a `inventory.commands` (tópico interno de saga).

## Eventos Kafka consumidos

| Tópico | Consumer Group | Finalidade |
|---|---|---|
| `inventory.commands` | `inventory-service` | Reservar, confirmar ou liberar estoque na saga do OrderService |

## Dependências síncronas

Nenhuma.

## SLOs

| Métrica | Objetivo | Error Budget (30d) |
|---|---|---|
| Disponibilidade | ≥ 99.95% | 21 min/mês |
| Error rate (5xx) | < 0.05% das requisições | — |
| Latência P99 `GET /v1/inventory/{sellerId}/{skuId}` | < 50 ms | — |
| Latência P99 `POST /v1/inventory/availability/batch` | < 100 ms | — |
| Latência P99 `POST /v1/inventory/reservations` | < 200 ms | — |
| Lag de consumo `inventory.commands` (P95) | < 2 s | — |

## Regras de negócio principais

1. Reserva DEVE ser idempotente: mesma `x-idempotency-key` resulta na mesma reserva, sem dupla baixa.
2. Disponibilidade retornada em consultas deve considerar estoque livre (total menos reservas ativas).
3. Reserva DEVE expirar automaticamente se não confirmada em X minutos (configurável).
4. Consumer de `inventory.commands` DEVE implementar Inbox Pattern para garantir exactly-once.

## Decisões arquiteturais relacionadas

- [ADR-0007 — Tópicos internos de saga](../adr/0007-order-service-internal-saga-topics.md)
- [ADR-0002 — Saga Orchestrator](../adr/0002-saga-orchestrator-pattern.md)
- [ADR-0005 — Estratégia de Idempotência](../adr/0005-idempotency-strategy.md)
