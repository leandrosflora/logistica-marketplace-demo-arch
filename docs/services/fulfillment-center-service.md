# Fulfillment Center Service

## Responsabilidade

Gerencia capacidade operacional, horários de cutoff e disponibilidade dos centros de distribuição (CDs/FCs). Informa ao `Shipping Promise Service` se o CD de origem tem capacidade para processar o pedido dentro do prazo prometido.

## Dados dominados

- **FulfillmentCenter**: dados de capacidade, localização, cutoff diário e janelas operacionais.
- **CapacityWindow**: capacidade disponível por janela de tempo em cada FC.

## APIs publicadas

| Método | Endpoint | Descrição |
|---|---|---|
| `GET` | `/v1/fulfillment-centers/{fcId}/capacity` | Consulta capacidade e cutoff do FC |
| `GET` | `/v1/fulfillment-centers/{fcId}/availability` | Verifica disponibilidade operacional para uma janela |

## Eventos Kafka publicados

Nenhum canônico. Responde a `fulfillment.commands` (tópico interno de saga).

## Eventos Kafka consumidos

| Tópico | Consumer Group | Finalidade |
|---|---|---|
| `fulfillment.commands` | `fulfillment-center-service` | Validar/ativar capacidade durante a saga do pedido |

## Dependências síncronas

Nenhuma.

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
