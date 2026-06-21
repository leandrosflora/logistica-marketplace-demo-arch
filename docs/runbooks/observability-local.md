# Runbook — Observabilidade Local

## Objetivo

Inicializar e usar a stack de observabilidade local (Prometheus, Grafana, Jaeger) para diagnosticar requisições E2E, visualizar métricas e rastrear spans entre microservices do case Logística Envios.

Decisão arquitetural relacionada: [ADR-0006 — Stack de Observabilidade](../adr/0006-observability-stack.md).

---

## URLs de acesso

| Componente | URL | Credenciais |
|---|---|---|
| Jaeger UI | `http://localhost:16686` | Nenhuma |
| Prometheus | `http://localhost:9090` | Nenhuma |
| Grafana | `http://localhost:3000` | `admin` / `logistica` |
| Kafka UI | `http://localhost:8088` | Nenhuma |

---

## Inicializar a stack

### Apenas infraestrutura base (Kafka, Redis, Postgres)

```bash
docker compose up -d
```

### Infraestrutura base + observabilidade

```bash
docker compose --profile observability up -d
```

Verificar todos os containers:

```bash
docker compose --profile observability ps
```

### Parar e resetar

```bash
docker compose --profile observability down -v
```

---

## Configurar um microservice .NET 8 para observabilidade

### 1. Adicionar pacotes NuGet

```xml
<PackageReference Include="OpenTelemetry.Extensions.Hosting" Version="1.9.*" />
<PackageReference Include="OpenTelemetry.Instrumentation.AspNetCore" Version="1.9.*" />
<PackageReference Include="OpenTelemetry.Instrumentation.Http" Version="1.9.*" />
<PackageReference Include="OpenTelemetry.Exporter.OpenTelemetryProtocol" Version="1.9.*" />
<PackageReference Include="OpenTelemetry.Instrumentation.Runtime" Version="1.9.*" />
```

### 2. Configurar em Program.cs

```csharp
builder.Services.AddOpenTelemetry()
    .WithTracing(tracing =>
    {
        tracing
            .AddAspNetCoreInstrumentation()
            .AddHttpClientInstrumentation()
            .AddSource("LogisticaEnvios.*")
            .SetResourceBuilder(ResourceBuilder.CreateDefault()
                .AddService(serviceName: "shipment-service", serviceVersion: "1.0.0"))
            .AddOtlpExporter(opts =>
            {
                opts.Endpoint = new Uri("http://localhost:4317");
                opts.Protocol = OtlpExportProtocol.Grpc;
            });
    })
    .WithMetrics(metrics =>
    {
        metrics
            .AddAspNetCoreInstrumentation()
            .AddRuntimeInstrumentation()
            .AddPrometheusExporter();
    });

// Expor endpoint /metrics para Prometheus
app.MapPrometheusScrapingEndpoint();
```

### 3. Configurar appsettings.Development.json

```json
{
  "OpenTelemetry": {
    "OtlpEndpoint": "http://localhost:4317",
    "ServiceName": "shipment-service"
  }
}
```

### 4. Propagar correlationId como atributo OTEL

```csharp
// Middleware para propagar x-correlation-id como atributo OTEL
app.Use(async (context, next) =>
{
    var correlationId = context.Request.Headers["x-correlation-id"].FirstOrDefault()
        ?? Guid.NewGuid().ToString();

    context.Response.Headers["x-correlation-id"] = correlationId;

    var activity = Activity.Current;
    activity?.SetTag("correlation.id", correlationId);

    await next();
});
```

---

## Rastrear uma requisição E2E no Jaeger

1. Acesse `http://localhost:16686`.
2. No campo **Service**, selecione o serviço de entrada (ex: `checkout-service`).
3. Clique em **Find Traces**.
4. Selecione um trace da lista.
5. Visualize os spans por serviço na linha do tempo.
6. Para buscar por `correlationId`: use a busca por tag `correlation.id=<uuid>`.

### Correlacionar com eventos Kafka

O `correlationId` do envelope Kafka pode ser usado como tag de busca no Jaeger:

```bash
# Ver correlationId em mensagens Kafka
docker exec -it logistica-envios-kafka kafka-console-consumer \
  --bootstrap-server localhost:9092 \
  --topic order.created \
  --from-beginning \
  | jq '.correlationId'
```

Com o `correlationId`, busque no Jaeger por `correlation.id=<valor>` para ver todos os spans da jornada.

---

## Visualizar métricas no Grafana

1. Acesse `http://localhost:3000` (login: `admin` / `logistica`).
2. Vá em **Explore** → selecione datasource **Prometheus**.
3. Métricas úteis:
   - `http_server_duration_milliseconds_bucket` — latência HTTP por serviço.
   - `kafka_consumer_lag` — lag de consumer groups.
   - `process_runtime_dotnet_gc_heap_size_bytes` — uso de heap .NET.

### Dashboards pré-configurados

Os dashboards provisionados estão em `monitoring/grafana/provisioning/dashboards/`.

Para importar dashboards da comunidade Grafana (ex: ASP.NET Core), use o ID do dashboard em **Dashboards → Import**.

---

## Verificar métricas do Prometheus

```bash
# Verificar targets configurados
curl http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | {job: .labels.job, health: .health}'

# Consultar métrica específica
curl 'http://localhost:9090/api/v1/query?query=up'
```

---

## Pontos de atenção

1. A stack de observabilidade usa `--profile observability` e NÃO inicia automaticamente com `docker compose up -d`.
2. Microservices devem expor `/metrics` na porta configurada para scrape pelo Prometheus.
3. O endpoint OTLP do Jaeger é `localhost:4317` (gRPC) ou `localhost:4318` (HTTP) para apps rodando fora do Docker.
4. Para apps dentro do Docker, use `jaeger:4317` como endpoint OTLP.
5. Dados de observabilidade são efêmeros: `docker compose down -v` remove volumes de Grafana e Prometheus.
