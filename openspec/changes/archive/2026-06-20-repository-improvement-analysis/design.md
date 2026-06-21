## Context

O repositório `meli-envios-architecture` é o repositório de contexto arquitetural do case Meli Envios, usado por agentes de IA (Codex, Claude Code) e desenvolvedores para guiar a implementação de 13+ microservices em .NET 8. O repositório possui boa base (diagramas C4, contratos Kafka canônicos, ADRs iniciais, runbooks e reviews), mas a análise identificou lacunas estruturais que comprometem a qualidade do contexto provido:

1. **ADRs ausentes**: decisões já em uso (Saga Orchestrator, arquitetura hexagonal, idempotência, versionamento de schema) não têm ADR correspondente.
2. **Ausência de glossário de domínio**: termos como "promise", "fulfillment center", "SLA", "SLO" são usados sem definição formal.
3. **Sem documentação de segurança**: propagação de identidade, autenticação e autorização entre serviços não são documentadas.
4. **Specs de serviço ausentes**: não há arquivo canônico de especificação por serviço (boundaries, SLOs, dependências).
5. **Observabilidade incompleta**: `docker-compose.yml` tem Kafka, Redis e Postgres, mas nenhum componente de observabilidade (Prometheus, Grafana, Jaeger).
6. **Schema governance informal**: versionamento de schemas Kafka é mencionado nas regras mas sem processo definido.
7. **Diagramas C4 incompletos**: apenas Order, Shipment e Tracking têm nível 3; os demais domínios não têm.
8. **Eventos canônicos incompletos**: `order.confirmed`, `order.cancelled`, `payment.approved`, `payment.rejected` e `shipment.cancelled` são mencionados nos ADRs mas não especificados em `kafka-events.md`.
9. **`shipment.created` sem `sellerId`**: consumidores como `notification-service` podem precisar do `sellerId` para personalização de comunicação com o seller.
10. **README desatualizado**: seção Estrutura não lista `docs/reviews/` e `docs/runbooks/`.

## Goals / Non-Goals

**Goals:**
- Criar todos os ADRs faltantes para decisões já adotadas no codebase.
- Criar glossário de domínio com termos do contexto de logística e envios.
- Criar documentação de arquitetura de segurança cobrindo autenticação, autorização e propagação de identidade.
- Criar specs individuais de microservice (um arquivo por serviço).
- Adicionar stack de observabilidade ao `docker-compose.yml` com runbook de uso.
- Criar documentação de schema governance Kafka.
- Criar diagramas C4 nível 3 para domínios sem cobertura.
- Documentar eventos canônicos ausentes em `kafka-events.md`.
- Adicionar `sellerId` ao payload de `shipment.created`.
- Atualizar README e AGENTS.md para refletir a nova estrutura.
- Criar documentação de pipeline CI/CD para microservices .NET 8.

**Non-Goals:**
- Implementar código nos repositórios de microservices.
- Criar Schema Registry real (ex: Confluent Schema Registry) — a documentação é textual/contratual.
- Gerar imagens SVG dos diagramas PlantUML automaticamente (isso é feito com o comando Docker já documentado).
- Criar infraestrutura real de CI/CD (pipelines GitHub Actions nos repos de microservices).

## Decisions

### D1: Estrutura de diretórios para novos artefatos

Novos diretórios sob `docs/`:
```text
docs/
├── adr/                      (existente — adicionar 0002 a 0006)
├── c4/                       (existente — adicionar .puml por domínio)
├── cicd/                     (novo)
│   └── pipeline.md
├── contracts/                (existente — atualizar kafka-events.md)
├── glossary/                 (novo)
│   └── domain-glossary.md
├── reviews/                  (existente)
├── runbooks/                 (existente — adicionar observability runbook)
├── security/                 (novo)
│   └── security-architecture.md
├── sequence-diagrams/        (existente)
└── services/                 (novo)
    ├── checkout-service.md
    ├── shipping-promise-service.md
    ├── product-catalog-service.md
    ├── inventory-service.md
    ├── fulfillment-center-service.md
    ├── routing-service.md
    ├── carrier-service.md
    ├── shipping-pricing-service.md
    ├── order-service.md
    ├── shipment-service.md
    ├── tracking-service.md
    ├── notification-service.md
    └── audit-service.md
```

Alternativa considerada: criar um único arquivo `services-specs.md` — rejeitada porque dificulta consulta por serviço individual e navegação via link direto no README.

### D2: Numeração e formato dos ADRs

Manter o formato já adotado (Markdown, seções Status/Contexto/Decisão/Consequências/Regras). Numeração sequencial a partir de 0002. Cada ADR cobre uma decisão distinta.

ADRs a criar:
- `0002-saga-orchestrator-pattern.md` — padrão Saga com orquestrador no OrderService.
- `0003-hexagonal-clean-architecture.md` — arquitetura hexagonal/clean obrigatória em todos os microservices.
- `0004-kafka-schema-versioning.md` — estratégia de versionamento de schemas Kafka.
- `0005-idempotency-strategy.md` — estratégia de idempotência com `x-idempotency-key` e Inbox/Outbox.
- `0006-observability-stack.md` — stack de observabilidade local (Prometheus, Grafana, Jaeger/OTEL).

### D3: Stack de observabilidade no docker-compose

Adicionar ao `docker-compose.yml`:
- **Prometheus**: scrape de métricas dos microservices via endpoint `/metrics` (porta configurável).
- **Grafana**: dashboards pré-configurados para Kafka lag, latência de APIs e health dos serviços.
- **Jaeger (all-in-one)**: collector OTEL + UI de traces em `http://localhost:16686`.

Alternativa considerada: Zipkin em vez de Jaeger — rejeitada porque Jaeger tem melhor suporte ao OpenTelemetry SDK do .NET.

Configuração base:
```yaml
jaeger:
  image: jaegertracing/all-in-one:1.57
  ports:
    - "16686:16686"   # UI
    - "4317:4317"     # OTLP gRPC
    - "4318:4318"     # OTLP HTTP

prometheus:
  image: prom/prometheus:v2.51.0
  ports:
    - "9090:9090"
  volumes:
    - ./monitoring/prometheus.yml:/etc/prometheus/prometheus.yml

grafana:
  image: grafana/grafana:10.4.0
  ports:
    - "3000:3000"
  environment:
    GF_SECURITY_ADMIN_PASSWORD: meli
  volumes:
    - ./monitoring/grafana/provisioning:/etc/grafana/provisioning
```

### D4: Schema governance Kafka — estratégia textual

Sem Schema Registry externo neste repositório. A governance é documentada em `docs/contracts/kafka-schema-governance.md` com:
- Regras de compatibilidade (backward-compatible por padrão).
- Processo de evolução: pull request com atualização de spec + ADR para mudanças incompatíveis.
- Versionamento via campo `schemaVersion` já presente no envelope.

### D5: Formato de spec de serviço

Cada arquivo em `docs/services/<nome>-service.md` segue template:
```markdown
# <Nome> Service

## Responsabilidade
## Dados dominados
## APIs publicadas
## Eventos Kafka publicados
## Eventos Kafka consumidos
## Dependências síncronas
## SLOs
## Regras de negócio principais
## Decisões arquiteturais relacionadas
```

### D6: Adição de `sellerId` em `shipment.created`

Adicionar campo `sellerId` ao payload canônico de `shipment.created` para que `notification-service` possa notificar o seller sem lookup adicional. O campo já existe no `order.created` upstream, portanto o `shipment-service` pode propagá-lo diretamente.

## Risks / Trade-offs

- **[Risco] Diagramas C4 nível 3 sem SVG gerado** → Mitigação: documentar o comando PlantUML Docker já existente no README como obrigatório após criação de novos `.puml`.
- **[Risco] `docker-compose.yml` pode ficar pesado com stack de observabilidade** → Mitigação: adicionar perfil Docker Compose `--profile observability` para que o stack seja opcional; a infra base (Kafka, Redis, Postgres) permanece leve.
- **[Risco] ADRs descrevem decisões retroativas, dificultando datação precisa** → Mitigação: usar data de criação do arquivo como "Data de registro" e marcar como "Decisão retroativa" no Status.
- **[Risco] Evento `shipment.created` com novo campo `sellerId` pode quebrar consumers existentes** → Mitigação: `sellerId` é adição backward-compatible; consumers que não precisam do campo simplesmente ignoram; incluir nota no `kafka-events.md` marcando como adição não-breaking em schemaVersion 1.1.

## Open Questions

- Definir SLOs numéricos por serviço requer alinhamento com times de produto — os arquivos de spec de serviço podem ter placeholders (`TBD`) inicialmente.
- A criação de dashboards Grafana pré-configurados requer JSON de provisioning — avaliar se manter como template ou criar dashboard mínimo funcional.
- Devemos documentar o `audit-service` com spec completa mesmo que não tenha repositório público listado no README?
