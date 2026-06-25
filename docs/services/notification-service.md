# Notification Service

## Responsabilidade real no código

Planeja, persiste e despacha notificações multicanal para destinatários, com suporte a:

- Email;
- SMS;
- Push;
- preferências de notificação;
- callbacks/receipts de provedores;
- consumo de eventos Kafka configurados.

## Dados dominados

- **Notification**: notificação planejada/enfileirada.
- **NotificationDelivery**: tentativa e status de envio por canal.
- **NotificationPreference**: preferência por destinatário, tipo e canal.
- **Inbox/Outbox**: controle de consumo/publicação interna conforme implementação do serviço.

## APIs publicadas

| Método | Endpoint | Descrição |
|---|---|---|
| `GET` | `/v1/notifications/{notificationId}` | Retorna status de uma notificação e suas entregas |
| `POST` | `/v1/notifications/tracking-status-changed` | Recebe evento de tracking por HTTP e planeja notificação |
| `PUT` | `/v1/notification-preferences/{recipientId}/{type}/{channel}` | Cria ou atualiza preferência de notificação |
| `POST` | `/v1/providers/{provider}/receipts` | Recebe receipt/callback de provedor externo |
| `GET` | `/health` | Health check |
| `GET` | `/health/live` | Liveness |
| `GET` | `/health/ready` | Readiness |

## Eventos Kafka publicados

Nenhum evento canônico de domínio foi localizado.

O serviço possui `OutboxDispatcher`, mas sua responsabilidade prática é suporte ao fluxo interno de dispatch/entrega, não publicação de eventos canônicos de negócio.

## Eventos Kafka consumidos configurados

| Tópico | Situação prática |
|---|---|
| `order.created` | Producer implementado no `OrderService` |
| `order.confirmed` | Consumer configurado, mas producer canônico não localizado; `OrderService` escreve confirmação em `order.events` |
| `order.cancelled` | Consumer configurado, mas producer canônico não localizado; `OrderService` escreve cancelamento em `order.events` |
| `payment.rejected` | Consumer configurado, mas producer ausente porque não há `PaymentService` implementado |
| `shipment.created` | Producer implementado no `ShipmentService` |
| `shipment.status.updated` | Producer implementado no `TrackingService` |
| `shipment.cancelled` | Consumer configurado, mas producer ausente no `ShipmentService` atual |

## Dependências síncronas

| Dependência | Uso |
|---|---|
| Provedor de Email | Envio de notificações por email |
| Provedor de SMS | Envio de SMS |
| Provedor de Push | Envio de push notification |

As chamadas usam `HttpClient` com políticas de resiliência.

## Persistência e infraestrutura

| Recurso | Uso |
|---|---|
| Postgres `NotificationDb` | Notifications, deliveries, preferences, inbox/outbox |
| Kafka | Consumo de eventos configurados |
| Redis | Não registrado no bootstrap atual |
| OpenTelemetry | Tracing, metrics e exporter OTLP |

A matriz consolidada de dados fica em [data-stores.md](../contracts/data-stores.md).

## SLOs sugeridos

| Métrica | Objetivo |
|---|---|
| Disponibilidade | ≥ 99.5% |
| Taxa de entrega ao provider | ≥ 99% |
| Lag Kafka/evento recebido → notificação planejada P95 | < 10 s |
| Tempo enfileirada → entregue ao provider P95 | < 30 s |

## Regras práticas

1. Consumers Kafka devem manter idempotência para evitar notificações duplicadas.
2. Notificações devem respeitar preferências por destinatário, tipo e canal.
3. Falhas de provider devem passar por retry/backoff antes de falha final.
4. Tópicos configurados sem producer não devem ser tratados como fluxo validado.
5. `payment.rejected`, `order.confirmed`, `order.cancelled` e `shipment.cancelled` são dependências configuradas, mas não E2E comprovado no código atual.

## Decisões arquiteturais relacionadas

- [ADR-0001 — Arquitetura orientada a eventos](../adr/0001-use-event-driven-architecture.md)
- [ADR-0005 — Estratégia de Idempotência](../adr/0005-idempotency-strategy.md)
