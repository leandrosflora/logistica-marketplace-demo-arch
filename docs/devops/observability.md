# Observabilidade

## Objetivo

Rastreabilidade ponta a ponta e sinais operacionais para detecção, diagnóstico e resolução de incidentes na plataforma Logística Envios.

---

## Stack

| Camada | Ferramenta | Finalidade |
|---|---|---|
| Instrumentação | OpenTelemetry SDK (.NET) | Traces, métricas e logs em padrão aberto |
| Traces | Jaeger (local) / AWS X-Ray (prod) | Rastreio distribuído entre serviços |
| Métricas | Prometheus + Grafana | Coleta, armazenamento e dashboards |
| Logs | JSON estruturado + OTLP -> OpenTelemetry Collector -> Loki (local) / CloudWatch ou OpenSearch (prod) | Busca e correlacao por `traceId` |

Todos os microservices DEVEM emitir os três sinais (traces, métricas, logs) via `OpenTelemetry.Extensions.Hosting`.

---

## Propagação de contexto

| Campo | Veículo HTTP | Veículo Kafka | Obrigatoriedade |
|---|---|---|---|
| `traceId` / `spanId` | `traceparent` (W3C) | Header Kafka `traceparent` | Obrigatório |
| `tracestate` | `tracestate` (W3C) | Header Kafka `tracestate` | Opcional; propagar quando existir |
| `x-correlation-id` | Header HTTP | Envelope Kafka `correlationId` | Obrigatório |
| `x-idempotency-key` | Header HTTP (writes) | — | Obrigatório em comandos |

### Kafka e W3C Trace Context

Todos os producers e consumers Kafka relevantes para a jornada de checkout/envio registram o `ActivitySource` compartilhado `Meli.Kafka` e exportam spans via OTLP para o Jaeger.

Os producers DEVEM:

- criar span `Kafka produce <topic>` com `ActivityKind.Producer`;
- adicionar tags `messaging.system=kafka`, `messaging.destination.name`, `messaging.kafka.topic`, `messaging.event.name` e `correlation.id`;
- injetar nos headers Kafka `traceparent` e, quando existir, `tracestate`;
- manter headers de diagnóstico existentes, como `eventType` e `correlationId`.

Os consumers DEVEM:

- extrair `traceparent`/`tracestate` dos headers Kafka;
- criar span `Kafka consume <topic>` com `ActivityKind.Consumer`;
- criar span filho `Process <event-name>` ao executar a regra de negócio do evento/comando;
- garantir que chamadas HTTP, banco de dados e novos publishes Kafka executem com o span de processamento como `Activity.Current`.

Nomes padronizados:

| Tipo | Nome |
|---|---|
| API HTTP | `HTTP <METHOD> <ROUTE>` via instrumentação AspNetCore |
| Producer Kafka | `Kafka produce <topic>` |
| Consumer Kafka | `Kafka consume <topic>` |
| Processamento | `Process <event-name>` |

Serviços instrumentados com spans Kafka: `checkout-service`, `shipping-promise-service`, `order-service`, `inventory-service`, `fulfillment-center-service`, `payment-service`, `shipment-service`, `tracking-service`, `notification-service`, `audit-service` e `order-visibility-service`.

---

## Formato de log

Todos os microservices emitem logs em JSON estruturado para stdout:

```json
{
  "timestamp": "2026-06-21T10:00:00.000Z",
  "level": "Information",
  "service": "checkout-service",
  "traceId": "4bf92f3577b34da6a3ce929d0e0e4736",
  "spanId": "00f067aa0ba902b7",
  "correlationId": "uuid",
  "message": "Checkout confirmado com sucesso",
  "checkoutId": "uuid",
  "durationMs": 143
}
```

---

## Golden Signals por categoria de serviço

### Caminho crítico de cotação

Serviços: `shipping-promise-service`, `checkout-service`, `inventory-service`, `routing-service`, `fulfillment-center-service`, `product-catalog-service`, `carrier-service`, `shipping-pricing-service`.

| Signal | Métrica Prometheus | Threshold de alerta |
|---|---|---|
| Traffic | `http_requests_total{service="..."}` | — (referência para baseline) |
| Latency | `http_request_duration_seconds{quantile="0.99"}` | > SLO por serviço (ver tabela abaixo) |
| Errors | `http_requests_total{status=~"5.."}` / total | > 0.5% por 5 min |
| Saturation | `process_cpu_usage`, `dotnet_gc_heap_size_bytes` | CPU > 80% por 10 min |

### Saga do pedido

Serviços: `order-service`, `payment-service`, `shipment-service`.

| Signal | Métrica | Threshold de alerta |
|---|---|---|
| Saga completion rate | `saga_completed_total` / `saga_started_total` | < 99.5% em janela de 15 min |
| Saga duration P95 | `saga_duration_seconds{quantile="0.95"}` | > 30 s |
| Payment rejection rate | `payment_rejected_total` / `payment_attempted_total` | > 15% em janela de 10 min |
| Compensation rate | `saga_compensation_triggered_total` | > 2% em janela de 15 min |

### Streaming e Kafka

| Signal | Métrica | Threshold de alerta |
|---|---|---|
| Consumer lag | `kafka_consumer_lag{topic="..."}` | > 1000 mensagens por 5 min |
| Processing time P95 | `kafka_message_processing_duration_seconds{quantile="0.95"}` | > SLO de lag por tópico |
| Dead letter queue | `kafka_dlq_messages_total` | > 0 em qualquer janela |
| Outbox relay lag | `outbox_pending_events_count` | > 50 por 2 min |

---

## Thresholds de alerta por serviço

| Serviço | Latência P99 alerta | Disponibilidade mínima | Kafka lag alerta |
|---|---|---|---|
| `checkout-service` | > 300 ms | < 99.9% | lag `shipping.promise.calculated` > 10 s |
| `shipping-promise-service` | > 1 s (síncrono) | < 99.9% | > 10 s para publicar promise |
| `inventory-service` | > 100 ms | < 99.95% | lag `inventory.commands` > 5 s |
| `routing-service` | > 300 ms | < 99.9% | — |
| `fulfillment-center-service` | > 200 ms | < 99.9% | lag `fulfillment.commands` > 5 s |
| `product-catalog-service` | > 100 ms | < 99.95% | — |
| `carrier-service` | > 1.5 s | < 99.5% | — |
| `shipping-pricing-service` | > 250 ms | < 99.9% | — |
| `order-service` | > 1 s | < 99.9% | saga duration > 45 s |
| `payment-service` | > 6 s (autorização) | < 99.9% | lag `payment.commands` > 5 s |
| `shipment-service` | > 300 ms | < 99.9% | tempo até `shipment.created` > 90 s |
| `tracking-service` | > 200 ms | < 99.9% | lag eventos de carrier > 20 s |
| `notification-service` | — | < 99.5% | lag qualquer tópico > 30 s |
| `audit-service` | > 800 ms | < 99.5% | lag qualquer tópico > 15 s |

---

## Dashboards Grafana

### Dashboard: Cotação de Frete (Visão Geral)

**Painéis:**
- Taxa de cotações bem-sucedidas (`available: true`) por janela de 5 min
- Latência P50/P99 do fluxo ponta a ponta: `POST /api/web/v1/shipping-promises`
- Latência por etapa: Catalog → Inventory → FC → Routing → Carrier → Pricing
- Consumer lag de `checkout.shipping.quote.requested` (fila de cotações pendentes)
- Taxa de uso de cache vs. cálculo em tempo real por serviço

### Dashboard: Saga do Pedido

**Painéis:**
- Funil da saga: `checkout.confirmed` → `order.created` → `payment.approved` → `order.confirmed`
- Taxa de compensações por etapa (estoque, fulfillment, pagamento)
- Duração P50/P95 da saga completa
- Taxa de rejeição de pagamento por `rejectionCode`
- Pedidos em estado `PendingReservations` há mais de 60 s (anomalia)

### Dashboard: Kafka Health

**Painéis:**
- Consumer lag por tópico (linha do tempo)
- Throughput de mensagens por tópico (msg/s)
- Taxa de mensagens na DLQ por tópico
- Outbox relay: mensagens pendentes no banco aguardando publicação
- Tempo de processamento P95 por consumer group

### Dashboard: SLO Compliance

**Painéis:**
- Error budget consumido por serviço (% do mês restante)
- Disponibilidade acumulada no mês por serviço (uptime %)
- Latência P99 por endpoint crítico vs. SLO definido
- Histórico de violações de SLO (últimos 30 dias)

---

## Regras de alerta (AlertManager / AWS CloudWatch Alarms)

```yaml
# Latência crítica no caminho de cotação
- alert: HighLatencyShippingPromise
  expr: http_request_duration_seconds{service="shipping-promise-service",quantile="0.99"} > 1
  for: 2m
  labels:
    severity: critical
    team: logistica-envios
  annotations:
    summary: "P99 do ShippingPromiseService acima de 1s"
    runbook: "docs/runbooks/shipping-promise-latency.md"

# Saga com alta taxa de compensações
- alert: HighSagaCompensationRate
  expr: rate(saga_compensation_triggered_total[10m]) / rate(saga_started_total[10m]) > 0.02
  for: 5m
  labels:
    severity: warning
  annotations:
    summary: "Taxa de compensações da saga acima de 2%"

# Consumer lag elevado (qualquer tópico canônico)
- alert: KafkaConsumerLagHigh
  expr: kafka_consumer_lag{topic=~"checkout.*|order.*|shipment.*|payment.*"} > 1000
  for: 5m
  labels:
    severity: warning
  annotations:
    summary: "Consumer lag elevado no tópico {{ $labels.topic }}"

# Mensagens na DLQ (tolerância zero)
- alert: KafkaDLQNonEmpty
  expr: kafka_dlq_messages_total > 0
  for: 1m
  labels:
    severity: critical
  annotations:
    summary: "Mensagens na Dead Letter Queue do tópico {{ $labels.topic }}"
    runbook: "docs/runbooks/kafka-dlq-investigation.md"

# Error budget crítico (< 10% restante no mês)
- alert: ErrorBudgetCritical
  expr: slo_error_budget_remaining_ratio < 0.10
  for: 0m
  labels:
    severity: critical
  annotations:
    summary: "Error budget do serviço {{ $labels.service }} abaixo de 10%"

# Alta taxa de rejeição de pagamento
- alert: HighPaymentRejectionRate
  expr: rate(payment_rejected_total[10m]) / rate(payment_attempted_total[10m]) > 0.15
  for: 5m
  labels:
    severity: warning
  annotations:
    summary: "Taxa de rejeição de pagamento acima de 15% nos últimos 10 min"
```

---

## Rastreio distribuído — Traces esperados

Para cada requisição ao BFF, os seguintes spans devem aparecer no Jaeger:

```
POST /api/web/v1/checkouts
└── checkout-service: CreateCheckout
    └── postgres: INSERT checkout
    └── kafka-producer: checkout.shipping.quote.requested
        └── shipping-promise-service: ConsumeQuoteRequest
            ├── product-catalog-service: GetPhysicalInfo (batch)
            ├── inventory-service: GetAvailability (batch)
            ├── fulfillment-center-service: SearchCandidates
            ├── routing-service: SearchRoutes
            ├── carrier-service: SearchAvailability
            └── shipping-pricing-service: CalculatePrices (batch)
        └── kafka-producer: shipping.promise.calculated
            └── checkout-service: ConsumePromise
                └── postgres: UPDATE checkout (ShippingPromiseProjection)
```

Todos os spans devem incluir: `traceId`, `spanId`, `parentSpanId`, `service.name`, `duration`, `http.status_code` e `db.statement` (quando aplicável).

---

## Validação de trace Kafka ponta a ponta

Exemplo esperado para a jornada de checkout/envio no Jaeger:

```text
HTTP POST /api/web/v1/checkouts
└── checkout-service: postgres INSERT checkout
└── Kafka produce checkout.shipping.quote.requested
    └── Kafka consume checkout.shipping.quote.requested
        └── Process checkout.shipping.quote.requested
            ├── HTTP GET/POST product-catalog/inventory/fulfillment/routing/carrier/pricing
            └── Kafka produce shipping.promise.calculated
                └── Kafka consume shipping.promise.calculated
                    └── Process shipping.promise.calculated
                        └── postgres UPDATE checkout (ShippingPromiseProjection)

HTTP POST /api/web/v1/checkouts/{id}/confirm
└── Kafka produce checkout.confirmed
    └── Kafka consume checkout.confirmed
        └── Process checkout.confirmed
            └── Kafka produce order.created / inventory.commands / fulfillment.commands
                ├── Kafka consume inventory.commands
                ├── Kafka consume fulfillment.commands
                ├── Kafka consume payment.commands
                ├── Kafka consume shipment.commands
                └── Kafka consume order.events
```

Passos de validação:

1. Suba a stack local com Jaeger/OTLP (`docker compose --profile observability up`) e execute os serviços relevantes apontando `OpenTelemetry:OtlpEndpoint` para `http://localhost:5107`.
2. Execute uma jornada completa de checkout/envio: criação de checkout, confirmação, criação de pedido, reservas, pagamento, envio e eventos finais da saga.
3. Abra `http://localhost:16686`.
4. Pesquise pelo `service.name` de entrada, normalmente `CheckoutService` ou `MarketplaceWeb.Bff`.
5. Confirme que o trace possui um único `traceId` atravessando spans HTTP, `Kafka produce <topic>`, `Kafka consume <topic>` e `Process <event-name>`.
6. Se tiver o `correlationId`, pesquise pelos spans com tag `correlation.id=<valor>` para conferir todos os trechos da jornada.

Limitações conhecidas:

- Alguns dispatchers baseados em outbox publicam mensagens em background depois que a activity HTTP/consumer original já terminou. Quando o outbox ainda não persiste `traceparent`/`tracestate`, o publish span pode iniciar um novo trecho de trace, embora ainda carregue `correlation.id`. A evolução recomendada é persistir `traceparent` e `tracestate` junto do registro de outbox.
- Eventos antigos ou produzidos antes desta instrumentação podem não conter headers W3C; consumers continuam processando esses casos, mas o Jaeger pode mostrar traces separados.

## Runbooks relacionados

- [Kafka local E2E](../runbooks/kafka-local-e2e.md) — validação de fluxo completo em ambiente local
- [Latência no caminho de cotação](../runbooks/shipping-promise-latency.md) — diagnóstico de P99 elevado
- [DLQ Investigation](../runbooks/kafka-dlq-investigation.md) — investigação de mensagens na dead letter queue
