# Observability

## Objetivo
Rastreabilidade ponta a ponta e sinais operacionais para incidentes.

## OpenTelemetry
Todos os microservices emitem traces, métricas e logs.

## Tracing
Propagar traceId/spanId em HTTP e eventos (Kafka). Backend: Jaeger ou AWS X-Ray.

## Logs
Formato JSON: timestamp, service, traceId, spanId, level, message. Destino: CloudWatch/OpenSearch.

## Métricas (Golden Signals)
- Traffic: requests/s
- Latency: p50/p95
- Errors: taxa de erro por endpoint
- Saturation: CPU/memória e backlog (Kafka lag)

## Dashboards e alertas
Dashboards no Grafana. Alertas quando error rate > 2% ou latency p95 fora do SLO.
