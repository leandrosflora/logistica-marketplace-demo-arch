## ADDED Requirements

### Requirement: Stack de observabilidade adicionada ao docker-compose.yml
O arquivo `docker-compose.yml` SHALL conter serviços de observabilidade (Prometheus, Grafana, Jaeger) configurados sob o perfil Docker Compose `observability`.

#### Scenario: Serviços de observabilidade declarados no docker-compose
- **WHEN** o `docker-compose.yml` é lido
- **THEN** ele MUST conter o serviço `jaeger` com image `jaegertracing/all-in-one:1.57`, portas `16686:16686` (UI), `4317:4317` (OTLP gRPC) e `4318:4318` (OTLP HTTP)
- **THEN** ele MUST conter o serviço `prometheus` com image `prom/prometheus:v2.51.0`, porta `9090:9090`, e volume para arquivo de configuração `./monitoring/prometheus.yml`
- **THEN** ele MUST conter o serviço `grafana` com image `grafana/grafana:10.4.0`, porta `3000:3000`, e credenciais padrão documentadas

#### Scenario: Serviços de observabilidade são opcionais via profile
- **WHEN** `docker compose up -d` é executado sem flags adicionais
- **THEN** os serviços Kafka, Redis e Postgres DEVEM subir, mas Prometheus, Grafana e Jaeger NÃO DEVEM subir automaticamente
- **WHEN** `docker compose --profile observability up -d` é executado
- **THEN** todos os serviços, incluindo observabilidade, DEVEM subir

### Requirement: Arquivo de configuração Prometheus criado
O repositório SHALL conter o arquivo `monitoring/prometheus.yml` com configuração base para scrape de métricas dos microservices.

#### Scenario: Arquivo prometheus.yml existe e é válido
- **WHEN** o arquivo `monitoring/prometheus.yml` é lido
- **THEN** ele MUST conter `global.scrape_interval: 15s`
- **THEN** ele MUST conter jobs de scrape com targets configuráveis para os microservices (`localhost:<porta>/metrics`)
- **THEN** ele MUST conter scrape do próprio Kafka via JMX Exporter se disponível

### Requirement: Runbook de observabilidade criado
O repositório SHALL conter um runbook `docs/runbooks/observability-local.md` documentando como usar a stack de observabilidade local.

#### Scenario: Runbook de observabilidade criado
- **WHEN** o arquivo `docs/runbooks/observability-local.md` é lido
- **THEN** ele MUST conter: URL do Jaeger UI (`http://localhost:16686`), URL do Grafana (`http://localhost:3000`), URL do Prometheus (`http://localhost:9090`)
- **THEN** ele MUST conter instrução de como inicializar a stack com `--profile observability`
- **THEN** ele MUST descrever como configurar um microservice .NET 8 para enviar traces via OTLP (pacote NuGet e configuração de appsettings)
- **THEN** ele MUST descrever como visualizar traces de uma requisição end-to-end no Jaeger usando `correlationId`

### Requirement: Configuração OTEL documentada para microservices .NET 8
O runbook de observabilidade SHALL documentar os pacotes NuGet e configurações necessárias para instrumentar microservices com OpenTelemetry.

#### Scenario: Configuração OTEL documentada
- **WHEN** o runbook de observabilidade é lido
- **THEN** ele MUST listar os pacotes NuGet obrigatórios: `OpenTelemetry.Extensions.Hosting`, `OpenTelemetry.Instrumentation.AspNetCore`, `OpenTelemetry.Instrumentation.Http`, `OpenTelemetry.Exporter.OpenTelemetryProtocol`
- **THEN** ele MUST conter snippet de configuração em `Program.cs` para registrar OTEL com exporter para Jaeger via OTLP
