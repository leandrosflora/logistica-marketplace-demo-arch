# Environments

## Objetivo

Padronizar a topologia, sizing e requisitos de cada ambiente da plataforma Logística Envios — do desenvolvimento local até a produção multi-AZ.

---

## Visão geral

| Ambiente | Trigger de deploy | Namespace EKS | Aprovação |
|---|---|---|---|
| Development (local) | Manual — `docker compose up` | — | — |
| Homologação (staging) | Merge em `develop` | `logistica-staging` | Automático |
| Produção | Merge em `main` + approval | `logistica-prod` | Tech Lead / on-call |

---

## Development (local)

Ambiente de desenvolvimento roda integralmente via **Docker Compose** na máquina do desenvolvedor. Nenhuma dependência de infra AWS.

```yaml
# docker-compose.yml — infraestrutura local compartilhada
services:
  postgres:
    image: postgres:16
    environment:
      POSTGRES_PASSWORD: localdev
    ports: ["5432:5432"]

  redis:
    image: redis:7-alpine
    ports: ["6379:6379"]

  kafka:
    image: confluentinc/cp-kafka:7.6.1
    environment:
      CLUSTER_ID: MkU3OEVBNTcwNTJENDM2Qk
      KAFKA_NODE_ID: 1
      KAFKA_PROCESS_ROLES: broker,controller
      KAFKA_CONTROLLER_QUORUM_VOTERS: 1@kafka:29093
      KAFKA_LISTENERS: PLAINTEXT://kafka:29092,CONTROLLER://kafka:29093,PLAINTEXT_HOST://0.0.0.0:9092
      KAFKA_ADVERTISED_LISTENERS: PLAINTEXT://kafka:29092,PLAINTEXT_HOST://localhost:9092
      KAFKA_AUTO_CREATE_TOPICS_ENABLE: "false"
    ports: ["9092:9092"]

  jaeger:
    image: jaegertracing/all-in-one:1.57
    ports: ["16686:16686", "4317:4317"]   # UI + OTLP gRPC
    profiles: [observability]

  kafka-ui:
    image: provectuslabs/kafka-ui:latest
    environment:
      KAFKA_CLUSTERS_0_NAME: local
      KAFKA_CLUSTERS_0_BOOTSTRAPSERVERS: kafka:29092
    ports: ["8088:8080"]
```

**Convenções:**
- Cada serviço roda localmente via `dotnet run` ou `docker compose up <service>`
- Banco local compartilhado — um schema por serviço (`checkout`, `order`, `inventory`, ...)
- Kafka local sem autenticação (PLAINTEXT)
- Secrets via `appsettings.Development.json` — **nunca commitados**, cobertos pelo `.gitignore`

---

## Homologação (Staging)

Ambiente controlado para validação funcional antes de produção. Deploy automático a cada merge em `develop`.

### Infraestrutura AWS

| Recurso | Especificação | Observação |
|---|---|---|
| EKS | 2 nós `m7i.large` (2 vCPU / 8 GB cada) | Single-AZ, sem redundância |
| RDS PostgreSQL 16 | `db.t4g.medium` (2 vCPU / 4 GB), Multi-AZ: não | Snapshot diário |
| ElastiCache Redis 7 | `cache.t4g.micro`, cluster mode: off | 1 nó, sem replicação |
| Amazon MSK (Kafka) | 1 broker `kafka.t3.small` | `replication.factor=1` |
| Amazon ECR | Compartilhado com produção | Imagens com tag `develop-<sha>` |
| AWS Secrets Manager | Path: `/logistica/staging/` | Rotação manual |

### Sizing de pods em homologação

```yaml
resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 500m
    memory: 256Mi

autoscaling:
  minReplicas: 1
  maxReplicas: 3
```

`minReplicas: 1` — sem redundância em staging para reduzir custo.

### Acesso e DNS

| Endpoint | URL |
|---|---|
| BFF (testes de integração) | `https://staging-api.logistica-envios.internal` |
| Grafana | `https://grafana.staging.logistica-envios.internal` |
| Jaeger | `https://jaeger.staging.logistica-envios.internal` |
| Kafka UI | `https://kafka-ui.staging.logistica-envios.internal` |

Acesso via VPN corporativa. TLS via AWS Certificate Manager.

---

## Produção

Ambiente com alta disponibilidade, redundância multi-AZ e aprovação manual obrigatória.

### Infraestrutura AWS

| Recurso | Especificação | Observação |
|---|---|---|
| EKS | 3 nós `m7i.large` (mínimo), Auto Scaling Group até 10 nós | Multi-AZ: `sa-east-1a`, `sa-east-1b`, `sa-east-1c` |
| RDS PostgreSQL 16 | `db.r7g.large` (2 vCPU / 16 GB), Multi-AZ: sim | Backup automático — retenção 7 dias, PITR habilitado |
| ElastiCache Redis 7 | `cache.r7g.large`, cluster mode: off, 1 replica | Read replica em AZ secundária |
| Amazon MSK (Kafka) | 3 brokers `kafka.m5.large` | `replication.factor=3`, `min.insync.replicas=2` |
| Amazon ECR | Imagens com tag `<sha>` e `latest` | Lifecycle policy: retém últimas 30 imagens |
| AWS Secrets Manager | Path: `/logistica/prod/` | Rotação automática de senhas RDS a cada 30 dias |
| ALB | Application Load Balancer com WAF | TLS terminado no ALB, certificado via ACM |
| AWS VPC | CIDR `10.0.0.0/16` | Subnets privadas para EKS/RDS/MSK, subnet pública para ALB |

### Topologia de rede

```text
Internet
    │
   [ALB + WAF]          subnet pública (10.0.0.0/24, 10.0.1.0/24, 10.0.2.0/24)
    │
   [EKS nodes]          subnet privada (10.0.10.0/24, 10.0.11.0/24, 10.0.12.0/24)
    ├── [RDS Multi-AZ]  subnet privada (10.0.20.0/24, 10.0.21.0/24)
    ├── [ElastiCache]   subnet privada (10.0.22.0/24, 10.0.23.0/24)
    └── [MSK]           subnet privada (10.0.30.0/24, 10.0.31.0/24, 10.0.32.0/24)
```

Nenhum recurso de dados (RDS, Redis, MSK) tem acesso direto à internet — apenas os EKS nodes em subnet privada os acessam.

### Sizing de pods em produção

Ver [deployment.md — Resource sizing por categoria](deployment.md#resource-sizing-por-categoria-de-serviço).

Distribuição entre AZs garantida por `topologySpreadConstraints` configurado em todos os Deployments.

### Acesso e DNS

| Endpoint | URL | Autenticação |
|---|---|---|
| API pública (BFF) | `https://api.logistica-envios.com` | JWT Bearer |
| Grafana | `https://grafana.logistica-envios.internal` | SSO corporativo |
| Jaeger / AWS X-Ray | AWS Console + Jaeger interno | VPN + IAM |
| Prometheus | Interno ao cluster | `kubectl port-forward` |

---

## Gestão de configuração por ambiente

| Tipo | Development | Homologação | Produção |
|---|---|---|---|
| Segredos | `appsettings.Development.json` (local) | AWS Secrets Manager `/logistica/staging/` | AWS Secrets Manager `/logistica/prod/` |
| Configuração | `appsettings.json` | ConfigMap EKS | ConfigMap EKS |
| Kafka bootstrap | `localhost:9092` | MSK staging endpoint | MSK prod endpoint |
| Redis | `localhost:6379` | ElastiCache staging | ElastiCache prod |
| Banco | `localhost:5432` | RDS staging | RDS prod (Multi-AZ) |
| Traces | Jaeger local (`:16686`) | Jaeger staging | AWS X-Ray |
| Logs | stdout / console | CloudWatch `/logistica/staging` | CloudWatch `/logistica/prod` |

---

## Namespaces EKS

| Namespace | Finalidade |
|---|---|
| `logistica-prod` | Todos os microservices em produção |
| `logistica-staging` | Todos os microservices em homologação |
| `monitoring` | Prometheus, Grafana, Jaeger, OpenTelemetry Collector |
| `ingress-nginx` | NGINX Ingress Controller |
| `external-secrets` | External Secrets Operator |
| `cert-manager` | Cert-manager (TLS automático via ACM / Let's Encrypt) |

---

## Referências

- [Deployment Strategy → docs/devops/deployment.md](deployment.md)
- [CI/CD → docs/devops/ci-cd.md](ci-cd.md)
- [Observabilidade → docs/devops/observability.md](observability.md)
