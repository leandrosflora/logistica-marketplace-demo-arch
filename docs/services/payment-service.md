# Payment Service

## Responsabilidade

Autoriza, captura e cancela (void) pagamentos de pedidos em resposta a comandos da saga do `OrderService`. Não integra com um gateway/PSP real; usa um adaptador mock (`IPaymentGatewayAdapter`) que simula aprovação/recusa de forma determinística.

## Dados dominados

- **PaymentAuthorization**: autorização de pagamento associada a um pedido (`OrderId` único), com status (`Authorized`, `Declined`, `Captured`, `CaptureFailed`, `Voided`).
- **InboxMessage**: controle de idempotência de comandos consumidos de `payment.commands`.
- **OutboxMessage**: eventos produzidos para Kafka.

## APIs publicadas

| Método | Endpoint | Descrição |
|---|---|---|
| `GET` | `/payments/{orderId}` | Consulta o estado da autorização de pagamento de um pedido |
| `GET` | `/health/live` | Liveness check |
| `GET` | `/health/ready` | Readiness check (inclui conectividade com Postgres) |

## Eventos Kafka publicados

| Tópico | Quando | Payload |
|---|---|---|
| `payment.approved` | Autorização aprovada pelo gateway | `orderId`, `paymentId`, `buyerId`, `amount`, `currency`, `authorizedAt` |
| `payment.rejected` | Autorização recusada pelo gateway | `orderId`, `paymentId`, `buyerId`, `rejectionCode`, `rejectedAt` (contrato idêntico ao já consumido por `NotificationService`) |
| `payment.captured` | Captura de um pagamento previamente autorizado | `orderId`, `paymentId`, `capturedAt` |
| `payment.capture.failed` | Falha ao capturar (autorização inexistente ou em status inválido) | `orderId`, `paymentId`, `reason`, `failedAt` |

## Eventos Kafka consumidos

| Tópico | Consumer Group | Finalidade |
|---|---|---|
| `payment.commands` | `payment-service` | Autorizar (`AuthorizePayment`), capturar (`CapturePayment`) ou cancelar (`VoidPaymentAuthorization`) um pagamento, roteado por campo `commandType` no corpo da mensagem |

## Dependências síncronas

Nenhuma. Toda a integração ocorre via Kafka (`payment.commands` → eventos canônicos).

## Persistência e infraestrutura

| Recurso | Uso |
|---|---|
| Postgres schema `payment` | Persistência de `PaymentAuthorization`, Inbox e Outbox |
| Redis | Não utilizado |
| Kafka | Consumo de `payment.commands`; publicação de `payment.approved`, `payment.rejected`, `payment.captured`, `payment.capture.failed` |

A matriz consolidada de dados fica em [data-stores.md](../contracts/data-stores.md).

## SLOs sugeridos

| Métrica | Objetivo |
|---|---|
| Disponibilidade | ≥ 99.9% |
| Error rate 5xx | < 0.1% |
| Latência P99 `GET /payments/{orderId}` | < 100 ms |
| Lag de consumo `payment.commands` (P95) | < 2 s |

## Regras de negócio principais

1. Existe no máximo uma `PaymentAuthorization` por `OrderId`.
2. Consumer de `payment.commands` implementa Inbox Pattern (`MessageId`) para garantir exactly-once.
3. Captura só é válida a partir do status `Authorized`; em qualquer outro status, publica `payment.capture.failed` sem alterar o status atual.
4. Void é idempotente: reenviar o comando para uma autorização já `Voided` não gera erro nem republica evento.
5. Não há gateway de pagamento real integrado. `MockPaymentGatewayAdapter` recusa quando `amount <= 0` ou quando `paymentMethodToken` contém a substring configurada em `PaymentGateway:DeclineTokenSubstring` (padrão `"decline"`); aprova em qualquer outro caso.
6. `correlationId` do comando de origem (header Kafka) é propagado para os eventos publicados; na ausência do header, usa-se o `orderId` como `correlationId`.

## Decisões arquiteturais relacionadas

- [ADR-0007 — Tópicos internos de saga](../adr/0007-order-service-internal-saga-topics.md)
- [ADR-0002 — Saga Orchestrator](../adr/0002-saga-orchestrator-pattern.md)
- [ADR-0005 — Estratégia de Idempotência](../adr/0005-idempotency-strategy.md)
