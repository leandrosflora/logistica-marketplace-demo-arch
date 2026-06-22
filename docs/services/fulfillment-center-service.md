# Fulfillment Center Service

## Responsabilidade

Gerencia capacidade operacional, horários de cutoff e disponibilidade dos centros de distribuição (CDs/FCs). Informa ao `Shipping Promise Service` se o CD de origem tem capacidade para processar o pedido dentro do prazo prometido.

## Dados dominados

- **FulfillmentCenter**: dados de capacidade, localização, cutoff diário e janelas operacionais.
- **CapacityWindow**: capacidade disponível por janela de tempo em cada FC.

## APIs publicadas

| Método | Endpoint | Descrição |
|---|---|---|
| `POST` | `/v1/fulfillment-centers/candidates/search` | Busca FCs candidatos para origem de um pedido (usado pelo Shipping Promise Service) |
| `GET` | `/v1/fulfillment-centers/{fulfillmentCenterId}/capacity` | Consulta capacidade e cutoff do FC |
| `GET` | `/v1/fulfillment-centers/{fulfillmentCenterId}/status` | Verifica status operacional atual do FC |
| `POST` | `/v1/capacity-reservations` | Cria reserva de capacidade operacional no FC (saga de pedido) |
| `POST` | `/v1/capacity-reservations/{reservationId}/confirm` | Confirma reserva de capacidade |
| `POST` | `/v1/capacity-reservations/{reservationId}/release` | Libera reserva de capacidade (compensação de saga) |

## Eventos Kafka publicados

Nenhum canônico. Responde a `fulfillment.commands` (tópico interno de saga).

## Eventos Kafka consumidos

| Tópico | Consumer Group | Finalidade |
|---|---|---|
| `fulfillment.commands` | `fulfillment-center-service` | Validar/ativar capacidade durante a saga do pedido |

## Dependências síncronas

Nenhuma.

## Persistência e infraestrutura

| Recurso | Uso |
|---|---|
| Postgres schema `fulfillment` | Persistência de `FulfillmentCenter`, `CapacityWindow`, reservas de capacidade e Inbox |
| Redis | Cache opcional de capacidade e cutoff |
| Kafka | Consumo de `fulfillment.commands` |

A matriz consolidada de dados fica em [data-stores.md](../contracts/data-stores.md).

## SLOs

| Métrica | Objetivo | Error Budget (30d) |
|---|---|---|
| Disponibilidade | ≥ 99.9% | 43 min/mês |
| Error rate (5xx) | < 0.1% das requisições | — |
| Latência P99 `POST /v1/fulfillment-centers/candidates/search` | < 100 ms | — |
| Lag de consumo `fulfillment.commands` (P95) | < 2 s | — |

## Regras de negócio principais

1. Cutoff DEVE ser respeitado: consulta após o horário de cutoff do dia DEVE retornar disponibilidade para o próximo dia útil.
2. Capacidade deve considerar pedidos já confirmados para a janela (não apenas reservados).
3. Consumer de `fulfillment.commands` DEVE implementar Inbox Pattern.

## Decisões arquiteturais relacionadas

- [ADR-0007 — Tópicos internos de saga](../adr/0007-order-service-internal-saga-topics.md)
- [ADR-0002 — Saga Orchestrator](../adr/0002-saga-orchestrator-pattern.md)
