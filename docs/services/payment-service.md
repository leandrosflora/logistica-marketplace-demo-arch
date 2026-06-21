# Payment Service

## Responsabilidade

Autoriza e captura pagamentos do buyer via integrações com provedores externos (MercadoPago, bandeiras de cartão, Pix). Participa da saga de criação de pedido como etapa de autorização de pagamento, coordenada pelo `OrderProcessManager` do Order Service. É responsável também pelo estorno em caso de compensação da saga.

## Dados dominados

- **PaymentAuthorization**: registro de autorização de pagamento com `paymentAuthorizationId`, status (`Pending`, `Approved`, `Rejected`, `Captured`, `Refunded`), método de pagamento, valor e `orderId` de correlação.
- **PaymentCapture**: captura efetiva do valor autorizado após conclusão da saga com sucesso.
- **Refund**: estorno de valor capturado em cenários de cancelamento ou compensação.

## APIs publicadas

| Método | Endpoint | Descrição |
|---|---|---|
| `GET` | `/v1/payments/{paymentAuthorizationId}` | Retorna status e detalhes da autorização |
| `POST` | `/v1/payments/{paymentAuthorizationId}/capture` | Captura o valor autorizado (após confirmação da saga) |
| `POST` | `/v1/payments/{paymentAuthorizationId}/refund` | Estorna pagamento (compensação de saga ou cancelamento do buyer) |

Headers obrigatórios: `x-correlation-id`, `x-idempotency-key` (em POST), `Authorization`.

## Eventos Kafka publicados

| Tópico | Quando | Schema |
|---|---|---|
| `payment.approved` | Autorização aprovada pelo provedor externo | [kafka-events.md](../contracts/kafka-events.md#paymentapproved) |
| `payment.rejected` | Autorização rejeitada ou timeout com provedor | [kafka-events.md](../contracts/kafka-events.md#paymentrejected) |

Ambos os eventos são publicados via **Outbox Pattern** para garantir entrega even-once ao Kafka.

## Eventos Kafka consumidos

| Tópico | Consumer Group | Finalidade |
|---|---|---|
| `payment.commands` | `payment-service` | Receber comando de autorização, captura ou estorno da saga do Order Service |

## Dependências síncronas

| Serviço | Finalidade |
|---|---|
| MercadoPago API | Autorização e captura de pagamentos (Pix, cartão de crédito/débito) |
| Provedores de bandeira (Visa, Mastercard) | Processamento de cartões internacionais |

## SLOs

| Métrica | Objetivo | Error Budget (30d) |
|---|---|---|
| Disponibilidade | ≥ 99.9% | 43 min/mês |
| Error rate (5xx próprios — excluindo recusas do provedor) | < 0.1% | — |
| Latência P99 autorização (`payment.commands` → `payment.approved/rejected`) | < 5 s | — |
| Latência P99 `POST /v1/payments/{id}/capture` | < 2 s | — |
| Latência P99 `POST /v1/payments/{id}/refund` | < 3 s | — |
| Taxa de aprovação de autorizações | ≥ 85% (métrica de negócio, não de SLA interno) | — |

## Regras de negócio principais

1. Consumer de `payment.commands` DEVE implementar Inbox Pattern para garantir exactly-once no processamento de autorizações — um mesmo comando não pode gerar duas cobranças.
2. Autorização e captura são etapas distintas: autorizar bloqueia o saldo no banco do buyer; capturar efetiva a cobrança. A captura só ocorre após a saga concluída com sucesso.
3. Em caso de timeout com o provedor externo (> 4 s), DEVE publicar `payment.rejected` com `rejectionCode: timeout` para que a saga inicie compensações.
4. Estorno (`/refund`) DEVE ser idempotente: mesmo `x-idempotency-key` não gera dois estornos para o mesmo pedido.
5. `payment.approved` e `payment.rejected` DEVEM ser publicados via Outbox Pattern antes de responder ao comando.
6. O `orderId` DEVE ser propagado do `payment.commands` para todos os eventos publicados, para correlação na saga.
7. Circuit breaker DEVE ser aplicado em todas as integrações externas; o estado aberto resulta sempre em `payment.rejected` para não bloquear a saga indefinidamente.
8. Em caso de `payment.rejected`, o `OrderProcessManager` DEVE iniciar compensações de estoque e capacidade antes de publicar `order.cancelled`.

## Decisões arquiteturais relacionadas

- [ADR-0002 — Saga Orchestrator](../adr/0002-saga-orchestrator-pattern.md)
- [ADR-0007 — Tópicos internos de saga](../adr/0007-order-service-internal-saga-topics.md)
- [ADR-0005 — Estratégia de Idempotência](../adr/0005-idempotency-strategy.md)
- [ADR-0001 — Arquitetura orientada a eventos](../adr/0001-use-event-driven-architecture.md)
