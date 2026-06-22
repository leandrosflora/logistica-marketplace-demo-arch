# Notification Service

## Responsabilidade

Planeja e envia notificações ao buyer e ao seller sobre alterações relevantes no ciclo de vida do pedido e da entrega. Decide o canal de comunicação (email, push, SMS) com base no tipo de evento e nas preferências do destinatário.

## Dados dominados

- **NotificationPlan**: decisão de notificação planejada para um evento (canal, destinatário, conteúdo).
- **NotificationLog**: registro de notificações enviadas e seu status de entrega.

## APIs publicadas

| Método | Endpoint | Descrição |
|---|---|---|
| `GET` | `/v1/notifications/{notificationId}` | Retorna status de uma notificação |

## Eventos Kafka publicados

Nenhum (serviço de saída pura — não publica eventos canônicos).

## Eventos Kafka consumidos

| Tópico | Consumer Group | Finalidade |
|---|---|---|
| `order.created` | `notification-service` | Notificar buyer e seller sobre criação do pedido |
| `order.confirmed` | `notification-service` | Notificar confirmação do pedido |
| `order.cancelled` | `notification-service` | Notificar cancelamento |
| `payment.rejected` | `notification-service` | Notificar buyer sobre falha de pagamento |
| `shipment.created` | `notification-service` | Notificar buyer sobre criação da entrega e tracking code |
| `shipment.status.updated` | `notification-service` | Notificar atualizações de status de entrega |
| `shipment.cancelled` | `notification-service` | Notificar cancelamento da entrega |

## Dependências síncronas

| Serviço | Finalidade |
|---|---|
| Provedores de notificação externos | Email (SMTP/SES), Push (FCM/APNs), SMS |

## Persistência e infraestrutura

| Recurso | Uso |
|---|---|
| Postgres schema `notification` | Persistência de `NotificationPlan`, `NotificationLog`, preferências materializadas e Inbox |
| Redis | Cache opcional de preferências e canais de notificação |
| Kafka | Consumo de eventos de pedido, pagamento e shipment |

A matriz consolidada de dados fica em [data-stores.md](../contracts/data-stores.md).

## SLOs

| Métrica | Objetivo | Error Budget (30d) |
|---|---|---|
| Disponibilidade | ≥ 99.5% | 3.6 h/mês |
| Taxa de entrega de notificações (delivery rate) | ≥ 99% | — |
| Lag Kafka (evento recebido → notificação enfileirada) P95 | < 10 s | — |
| Tempo até envio pelo provider (enfileirada → entregue ao provider) P95 | < 30 s | — |

## Regras de negócio principais

1. Consumers Kafka DEVEM implementar Inbox Pattern para evitar notificações duplicadas.
2. Notificação ao buyer usa `buyerId` do evento; notificação ao seller usa `sellerId`.
3. Em caso de falha de envio, DEVE realizar retry com backoff antes de marcar como falha.
4. `NotificationPlanner` decide qual canal usar com base no tipo de evento e preferências do usuário.
5. Notificações NÃO DEVEM ser enviadas para buyer ou seller com notificações desabilitadas.

## Decisões arquiteturais relacionadas

- [ADR-0001 — Arquitetura orientada a eventos](../adr/0001-use-event-driven-architecture.md)
- [ADR-0005 — Estratégia de Idempotência](../adr/0005-idempotency-strategy.md)
