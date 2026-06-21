# Shipping Promise Service

## Responsabilidade

Calcula prazo, disponibilidade, modalidade e custo de entrega para um conjunto de itens e destino. É o serviço central do fluxo de cotação, orquestrando consultas síncronas a múltiplos domínios especializados para compor a promessa de entrega.

## Dados dominados

- **ShippingPromise**: resultado do cálculo de promessa, com `promiseId`, prazo, modalidade, carrier e custo.

## APIs publicadas

| Método | Endpoint | Descrição |
|---|---|---|
| `POST` | `/v1/shipping-promises` | Calcula promessa de entrega de forma síncrona (fallback) |
| `GET` | `/v1/shipping-promises/{promiseId}` | Retorna uma promessa calculada anteriormente |

## Eventos Kafka publicados

| Tópico | Quando | Schema |
|---|---|---|
| `shipping.promise.calculated` | Após calcular a promessa assíncrona | [kafka-events.md](../contracts/kafka-events.md#shippingpromisecalculated) |

## Eventos Kafka consumidos

| Tópico | Consumer Group | Finalidade |
|---|---|---|
| `checkout.shipping.quote.requested` | `shipping-promise-service` | Recebe solicitação de cotação assíncrona |

## Dependências síncronas

| Serviço | Finalidade |
|---|---|
| Product Catalog Service | Dimensões, peso e restrições do produto |
| Inventory Service | Disponibilidade de estoque por SKU/seller/FC |
| Fulfillment Center Service | Capacidade e cutoff do CD de origem |
| Routing Service | Rota logística e SLA |
| Carrier Service | Opções de transportadora e restrições |
| Shipping Pricing Service | Custo de frete e subsídios |

## SLOs

| Métrica | Objetivo |
|---|---|
| Disponibilidade | TBD |
| Latência P99 `POST /shipping-promises` | TBD (fluxo síncrono — crítico para UX) |
| Latência de publicação após consumo Kafka | TBD |

## Regras de negócio principais

1. O cálculo síncrono DEVE retornar fallback (promessa degradada) se alguma dependência estiver indisponível, nunca falhar completamente.
2. O `checkoutId` recebido no evento Kafka DEVE ser propagado na promessa publicada para correlação no `CheckoutService`.
3. A promessa DEVE incluir ao menos uma modalidade de entrega disponível ou retornar `no_options_available`.
4. Circuit breaker DEVE ser aplicado em todas as dependências síncronas.
5. Timeout explícito: máximo 500ms por dependência síncrona.

## Decisões arquiteturais relacionadas

- [ADR-0001 — Arquitetura orientada a eventos](../adr/0001-use-event-driven-architecture.md)
- [ADR-0003 — Arquitetura Hexagonal](../adr/0003-hexagonal-clean-architecture.md)
