# Checkout Service

## Responsabilidade

Orquestra a experiência de compra do ponto de vista do usuário: cotação de frete, confirmação de modalidade, autorização de pagamento e criação de pedido. É o ponto de entrada do fluxo de compra após o carrinho do buyer.

## Dados dominados

- **Checkout** (entidade em andamento): carrinho em processo de confirmação, com status, itens selecionados e promessa de entrega associada.
- **ShippingPromiseProjection**: projeção local da promessa recebida via Kafka para associar ao checkout.

## APIs publicadas

| Método | Endpoint | Descrição |
|---|---|---|
| `POST` | `/v1/checkouts` | Inicia um novo checkout |
| `GET` | `/v1/checkouts/{checkoutId}` | Retorna status e dados do checkout |
| `POST` | `/v1/checkouts/{checkoutId}/confirm` | Confirma o checkout e aciona criação de pedido |
| `GET` | `/v1/checkouts/{checkoutId}/shipping-options` | Retorna opções de frete calculadas |

Headers obrigatórios: `x-correlation-id`, `x-idempotency-key` (em POST/confirm), `Authorization`.

## Eventos Kafka publicados

| Tópico | Quando | Schema |
|---|---|---|
| `checkout.shipping.quote.requested` | Ao iniciar cotação de frete | [kafka-events.md](../contracts/kafka-events.md#checkoutshippingquoterequested) |
| `checkout.confirmed` | Ao confirmar o checkout (`POST /confirm`) | [kafka-events.md](../contracts/kafka-events.md#checkoutconfirmed) |

## Eventos Kafka consumidos

| Tópico | Consumer Group | Finalidade |
|---|---|---|
| `shipping.promise.calculated` | `checkout-service` | Recebe promessa calculada e projeta no checkout |

## Dependências síncronas

Nenhuma (fluxo de cotação é assíncrono via Kafka).

Dependências de infraestrutura: Redis (cache de promessa), Postgres (persistência do checkout).

## SLOs

| Métrica | Objetivo | Error Budget (30d) |
|---|---|---|
| Disponibilidade | ≥ 99.9% | 43 min/mês |
| Error rate (5xx) | < 0.1% das requisições | — |
| Latência P99 `POST /v1/checkouts` | < 200 ms | — |
| Latência P99 `POST /v1/checkouts/{id}/confirm` | < 300 ms | — |
| Latência P99 `GET /v1/checkouts/{id}/shipping-options` | < 100 ms | — |
| Lag de consumo `shipping.promise.calculated` (P95) | < 5 s desde publicação | — |

## Regras de negócio principais

1. Um checkout DEVE ter exatamente um buyer, um seller e pelo menos um item.
2. A confirmação do checkout SÓ pode ocorrer após recebimento de `shipping.promise.calculated` com o mesmo `checkoutId`.
3. Checkout expirado (sem promise em X minutos) DEVE ser descartado e o buyer notificado.
4. `POST /checkouts/{checkoutId}/confirm` DEVE ser idempotente via `x-idempotency-key`.
5. O `checkoutId` DEVE ser propagado em todos os eventos Kafka para correlação assíncrona.

## Decisões arquiteturais relacionadas

- [ADR-0001 — Arquitetura orientada a eventos](../adr/0001-use-event-driven-architecture.md)
- [ADR-0005 — Estratégia de Idempotência](../adr/0005-idempotency-strategy.md)
