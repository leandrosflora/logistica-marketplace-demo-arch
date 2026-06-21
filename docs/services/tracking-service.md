# Tracking Service

## Responsabilidade

Acompanha e processa eventos de rastreio de entrega, mantém a linha do tempo de status do shipment e publica atualizações de status para outros domínios. É a fonte de verdade para o estado atual de rastreio de um shipment.

## Dados dominados

- **TrackingTimeline**: linha do tempo de eventos de rastreio por `shipmentId`.
- **TrackingStatus**: status atual e histórico de mudanças de um shipment.

## APIs publicadas

| Método | Endpoint | Descrição |
|---|---|---|
| `GET` | `/v1/tracking/{trackingCode}` | Retorna linha do tempo de rastreio |
| `GET` | `/v1/tracking/shipments/{shipmentId}` | Retorna status atual e histórico |
| `POST` | `/v1/tracking/events` | Recebe evento de rastreio externo (carrier webhook) |

## Eventos Kafka publicados

| Tópico | Quando | Schema |
|---|---|---|
| `shipment.status.updated` | Status de entrega muda | [kafka-events.md](../contracts/kafka-events.md#shipmentstatusupdated) |

## Eventos Kafka consumidos

| Tópico | Consumer Group | Finalidade |
|---|---|---|
| `shipment.created` | `tracking-service` | Iniciar rastreio de um novo shipment |
| `shipment.cancelled` | `tracking-service` | Encerrar rastreio de um shipment cancelado |

## Dependências síncronas

| Serviço | Finalidade |
|---|---|
| APIs de transportadoras (polling ou webhook) | Receber eventos de rastreio externo |

## SLOs

| Métrica | Objetivo | Error Budget (30d) |
|---|---|---|
| Disponibilidade | ≥ 99.9% | 43 min/mês |
| Error rate (5xx) | < 0.1% das requisições | — |
| Latência P99 `GET /v1/tracking/{trackingCode}` (endpoint público) | < 100 ms | — |
| Latência P99 `GET /v1/tracking/shipments/{id}` | < 100 ms | — |
| Lag de processamento: recebimento de evento de carrier → publicação de `shipment.status.updated` (P95) | < 10 s | — |

## Regras de negócio principais

1. Consumer de `shipment.created` DEVE implementar Inbox Pattern.
2. `shipment.status.updated` DEVE ser publicado via Outbox Pattern.
3. `orderId` e `buyerId` DEVEM ser propagados do `shipment.created` para o `shipment.status.updated`.
4. Status DEVE ser idempotente: mesmo evento de carrier com mesmo timestamp não deve criar entrada duplicada.
5. Eventos de rastreio DEVEM ser armazenados em ordem cronológica; o status atual é sempre o mais recente.

## Decisões arquiteturais relacionadas

- [ADR-0005 — Estratégia de Idempotência](../adr/0005-idempotency-strategy.md)
- [ADR-0004 — Schema Versioning](../adr/0004-kafka-schema-versioning.md)
