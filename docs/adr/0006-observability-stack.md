# ADR-0006 — Stack de Observabilidade

## Status

Aceita

## Data

2026-06-20

## Contexto

Um ecossistema com 13+ microservices em comunicação síncrona e assíncrona requer observabilidade para diagnosticar falhas, medir performance e rastrear requisições de ponta a ponta. Os três pilares de observabilidade são:

- **Logs**: eventos textuais de execução por instância de serviço.
- **Métricas**: séries temporais numéricas (latência, throughput, error rate, Kafka lag).
- **Traces**: rastreio de uma requisição através de múltiplos serviços.

Opções consideradas:

- **ELK Stack + Prometheus + Zipkin**: popular, mas fragmentado em múltiplas ferramentas sem integração nativa.
- **OpenTelemetry + Prometheus + Grafana + Jaeger**: padrão aberto com SDK unificado para .NET, integração nativa entre traces e métricas.
- **Datadog/New Relic**: SaaS, não adequado para ambiente local de desenvolvimento.

## Decisão

Adotar **OpenTelemetry SDK** como abstração de instrumentação em todos os microservices, com:

- **Prometheus** para coleta e armazenamento de métricas.
- **Grafana** para dashboards de métricas.
- **Jaeger** para coleta e visualização de traces distribuídos.
- **Logs estruturados em JSON** exportados para `stdout` (sem coletor de log no ambiente local; CI/CD pode adicionar coletor).

### Stack local (docker-compose com profile `observability`)

| Componente | Imagem | Porta |
|---|---|---|
| Jaeger | `jaegertracing/all-in-one:1.57` | `16686` (UI), `4317` (OTLP gRPC), `4318` (OTLP HTTP) |
| Prometheus | `prom/prometheus:v2.51.0` | `9090` |
| Grafana | `grafana/grafana:10.4.0` | `3000` |

### Pacotes NuGet obrigatórios por microservice

```xml
<PackageReference Include="OpenTelemetry.Extensions.Hosting" Version="1.9.*" />
<PackageReference Include="OpenTelemetry.Instrumentation.AspNetCore" Version="1.9.*" />
<PackageReference Include="OpenTelemetry.Instrumentation.Http" Version="1.9.*" />
<PackageReference Include="OpenTelemetry.Exporter.OpenTelemetryProtocol" Version="1.9.*" />
<PackageReference Include="OpenTelemetry.Instrumentation.Runtime" Version="1.9.*" />
```

### Formato de log estruturado obrigatório

Campos obrigatórios em todos os logs:

```json
{
  "timestamp": "2026-06-20T12:00:00Z",
  "level": "Information",
  "service": "shipment-service",
  "correlationId": "uuid",
  "traceId": "hex-string",
  "spanId": "hex-string",
  "message": "Shipment created",
  "data": {}
}
```

### Propagação de contexto

O `correlationId` do envelope Kafka e do header HTTP `x-correlation-id` DEVE ser injetado como atributo OTEL (`correlation.id`) em todos os spans, permitindo correlação entre traces e eventos Kafka no Jaeger.

## Justificativa

OpenTelemetry é o padrão aberto de facto para instrumentação de aplicações distribuídas, com suporte nativo no .NET 8 via `System.Diagnostics.Activity` e `ActivitySource`. Prometheus e Grafana são amplamente adotados para métricas, e Jaeger é o backend de trace mais compatível com OTEL para ambiente local.

## Consequências positivas

- SDK único para logs, métricas e traces.
- Rastreio de requisições de ponta a ponta via `traceId`.
- Correlação entre `correlationId` de negócio e `traceId` técnico.
- Stack local reproduzível com docker-compose.

## Consequências negativas

- Stack de observabilidade consome recursos locais (RAM/CPU) adicionais.
- Custo de configuração inicial por microservice.
- Para ambiente de produção, exige backend adequado (ex: Jaeger com Cassandra, Grafana Cloud, etc.).

## Regras

1. Todo microservice DEVE instrumentar com OpenTelemetry SDK os spans de: requisições HTTP inbound/outbound, publicação e consumo Kafka, operações de banco de dados.
2. Logs DEVEM ser emitidos em JSON estruturado com os campos obrigatórios.
3. O `correlationId` DEVE ser propagado como atributo OTEL em todos os spans.
4. A stack de observabilidade local DEVE ser iniciada com `docker compose --profile observability up -d` (opcional, não bloqueia infra base).
5. Runbook de observabilidade: [`docs/runbooks/observability-local.md`](../runbooks/observability-local.md).

## Decisões relacionadas

- [ADR-0001 — Usar arquitetura orientada a eventos](0001-use-event-driven-architecture.md)
