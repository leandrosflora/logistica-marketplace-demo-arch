# Audit Service

## Responsabilidade

Mantém a rastreabilidade técnica, funcional e regulatória de todos os eventos relevantes do ecossistema Logística Envios. É o repositório imutável de auditoria que permite reconstituir o histórico completo de qualquer pedido, entrega ou pagamento.

## Dados dominados

- **AuditEntry**: registro imutável de evento auditado com `eventId`, `eventType`, `correlationId`, `occurredAt`, `producer`, `payload` e metadados técnicos.

## APIs publicadas

| Método | Endpoint | Descrição |
|---|---|---|
| `GET` | `/v1/audit/entries` | Consulta entradas de auditoria com filtros (correlationId, orderId, eventType, período) |
| `GET` | `/v1/audit/entries/{entryId}` | Retorna uma entrada específica de auditoria |

## Eventos Kafka publicados

Nenhum.

## Eventos Kafka consumidos

| Tópico | Consumer Group | Finalidade |
|---|---|---|
| `checkout.shipping.quote.requested` | `audit-service` | Auditar solicitação de cotação |
| `shipping.promise.calculated` | `audit-service` | Auditar promessa calculada |
| `order.created` | `audit-service` | Auditar criação de pedido |
| `order.confirmed` | `audit-service` | Auditar confirmação de pedido |
| `order.cancelled` | `audit-service` | Auditar cancelamento de pedido |
| `payment.approved` | `audit-service` | Auditar aprovação de pagamento |
| `payment.rejected` | `audit-service` | Auditar rejeição de pagamento |
| `shipment.created` | `audit-service` | Auditar criação de entrega |
| `shipment.status.updated` | `audit-service` | Auditar atualizações de status |
| `shipment.cancelled` | `audit-service` | Auditar cancelamento de entrega |

## Dependências síncronas

Nenhuma.

## SLOs

| Métrica | Objetivo | Error Budget (30d) |
|---|---|---|
| Disponibilidade | ≥ 99.5% | 3.6 h/mês |
| Perda de eventos de auditoria | 0% (tolerância zero) | — |
| Lag de persistência (consumo Kafka → entrada persistida) P95 | < 5 s | — |
| Latência P99 `GET /v1/audit/events` | < 500 ms | — |

## Regras de negócio principais

1. Entradas de auditoria são **imutáveis**: uma vez persistidas, NUNCA devem ser alteradas ou deletadas.
2. Consumer Kafka DEVE implementar Inbox Pattern; a mesma mensagem Kafka não deve gerar entradas duplicadas.
3. DEVE persistir o payload completo do evento para reconstituição histórica.
4. Consultas DEVEM suportar filtro por `correlationId` para rastrear uma jornada de ponta a ponta.
5. Retenção de dados: conforme política regulatória aplicável (TBD por times jurídico/compliance).

## Decisões arquiteturais relacionadas

- [ADR-0001 — Arquitetura orientada a eventos](../adr/0001-use-event-driven-architecture.md)
- [ADR-0005 — Estratégia de Idempotência](../adr/0005-idempotency-strategy.md)
