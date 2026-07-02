# Audit Service

## Responsabilidade

Mantém a rastreabilidade técnica de todos os eventos canônicos do ecossistema Logística Envios que têm producer real implementado. É um repositório imutável de auditoria (consumer-only, não publica eventos) que permite reconstituir, por `correlationId`, o histórico de uma jornada de ponta a ponta.

## Dados dominados

- **AuditEntry**: registro imutável de evento auditado com `eventId`, `eventType`, `schemaVersion`, `correlationId`, `occurredAt`, `producer`, `topic`, `partition`, `offset`, `payload` (JSON bruto do evento) e `metadata`.

## APIs publicadas

| Método | Endpoint | Descrição |
|---|---|---|
| `GET` | `/v1/audit/entries` | Lista entradas de auditoria filtráveis por `correlationId`, `eventType` e intervalo `occurredFrom`/`occurredTo`, paginado (`page`, `pageSize`, padrão 50, máximo 200) |
| `GET` | `/v1/audit/entries/{entryId}` | Retorna uma entrada específica de auditoria |
| `GET` | `/health/live` | Liveness check |
| `GET` | `/health/ready` | Readiness check (inclui conectividade com Postgres) |

Não há filtro por `orderId`: os payloads são heterogêneos entre os dez tópicos consumidos e não há um campo `orderId` consistente em todos eles, nem índice que suporte essa consulta. `correlationId` é o mecanismo suportado para rastrear uma jornada completa.

## Eventos Kafka publicados

Nenhum. `AuditService` é consumer-only.

## Eventos Kafka consumidos

Apenas tópicos canônicos com producer real implementado no conjunto atual (ver [kafka-events.md](../contracts/kafka-events.md)):

| Tópico | Consumer Group | Finalidade |
|---|---|---|
| `checkout.shipping.quote.requested` | `audit-service` | Auditar solicitação de cotação |
| `shipping.promise.calculated` | `audit-service` | Auditar promessa calculada |
| `checkout.confirmed` | `audit-service` | Auditar confirmação de checkout |
| `order.created` | `audit-service` | Auditar criação de pedido |
| `payment.approved` | `audit-service` | Auditar aprovação de pagamento |
| `payment.rejected` | `audit-service` | Auditar rejeição de pagamento |
| `payment.captured` | `audit-service` | Auditar captura de pagamento |
| `payment.capture.failed` | `audit-service` | Auditar falha de captura de pagamento |
| `shipment.created` | `audit-service` | Auditar criação de entrega |
| `shipment.status.updated` | `audit-service` | Auditar atualizações de status de entrega |

Um único consumer genérico (`AuditEventsConsumer`) assina todos os tópicos acima e persiste o envelope canônico bruto — não há handlers tipados por tópico, já que o serviço apenas preserva o payload, não interpreta seu conteúdo. Mensagens que falham ao desserializar como envelope canônico são logadas e descartadas sem bloquear a partição.

Tópicos historicamente cogitados para este serviço mas **sem producer real implementado** (`order.confirmed`, `order.cancelled`, `shipment.cancelled`) não são consumidos, para evitar repetir o descolamento entre documentação e código que levou à remoção da spec anterior deste serviço.

## Dependências síncronas

Nenhuma.

## Persistência e infraestrutura

| Recurso | Uso |
|---|---|
| Postgres schema `audit` | Persistência imutável de `AuditEntry` (`audit.audit_entries`) e inbox de idempotência (`audit.inbox_messages`) |
| Redis | Não utilizado; consultas de auditoria priorizam consistência forte |
| Kafka | Consumo dos dez tópicos acima; nenhuma publicação |

Acesso a dados via **Dapper + Npgsql** (não Entity Framework Core) — escolha arquitetural explícita para este serviço, seguindo o padrão já usado por `CheckoutService` (`IDatabaseContext`/`DatabaseContext` com transação explícita), não o padrão dominante de EF Core dos demais microservices.

A matriz consolidada de dados fica em [data-stores.md](../contracts/data-stores.md).

## SLOs sugeridos

| Métrica | Objetivo |
|---|---|
| Disponibilidade | ≥ 99.5% |
| Perda de eventos de auditoria | 0% (tolerância zero para mensagens válidas) |
| Lag de persistência (consumo Kafka → entrada persistida) P95 | < 5 s |
| Latência P99 `GET /v1/audit/entries` | < 500 ms |

## Regras de negócio principais

1. Entradas de auditoria são **imutáveis**: uma vez persistidas, nunca são alteradas ou deletadas (o repositório não expõe update/delete).
2. Consumer Kafka implementa Inbox Pattern (`audit.inbox_messages`, chave `event_id`); a mesma mensagem nunca gera entrada duplicada — inserção no inbox e na tabela de entradas ocorre na mesma transação.
3. Persiste o payload JSON bruto do evento (sem reinterpretar/tipar por evento), para reconstituição histórica fiel.
4. Consultas suportam filtro por `correlationId` para rastrear uma jornada de ponta a ponta.
5. Retenção de dados: ainda não definida (depende de política jurídica/compliance), como já era o caso antes deste serviço existir.

## Decisões arquiteturais relacionadas

- [ADR-0001 — Arquitetura orientada a eventos](../adr/0001-use-event-driven-architecture.md)
- [ADR-0005 — Estratégia de Idempotência](../adr/0005-idempotency-strategy.md)
