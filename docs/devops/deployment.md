# Deployment Strategy

## Objetivo

Entregar os microservices via containers no Amazon EKS com zero-downtime, rollback automático e isolamento claro de recursos por ambiente.

---

## Dockerfile — padrão multi-stage

Todos os serviços seguem o mesmo template multi-stage. O `stage build` usa a SDK completa; o `stage runtime` usa a imagem mínima ASP.NET Runtime e roda como usuário não-root.

```dockerfile
# Stage 1 — build
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src
COPY ["src/CheckoutService/CheckoutService.csproj", "src/CheckoutService/"]
RUN dotnet restore "src/CheckoutService/CheckoutService.csproj"
COPY . .
WORKDIR "/src/src/CheckoutService"
RUN dotnet publish -c Release -o /app/publish --no-restore

# Stage 2 — runtime
FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS runtime
WORKDIR /app

# Usuário não-root obrigatório — nunca rodar como root em prod
RUN addgroup --system appgroup && adduser --system --ingroup appgroup appuser
USER appuser

COPY --from=build /app/publish .
EXPOSE 8080
ENV ASPNETCORE_URLS=http://+:8080
ENTRYPOINT ["dotnet", "CheckoutService.dll"]
```

**Regras:**
- Imagem base fixada por digest no pipeline de produção (`mcr.microsoft.com/dotnet/aspnet:8.0@sha256:...`) via Renovate
- `HEALTHCHECK` não é adicionado no Dockerfile — o probe é gerenciado pelo Kubernetes (liveness/readiness)
- Nenhum secret ou configuração é embutido na imagem

---

## Tagging de imagem Docker

| Contexto | Tags geradas | Publicação ECR |
|---|---|---|
| PR / `feature/*` | Nenhuma | Não publicada |
| Merge em `develop` | `develop-<sha7>` | Sim |
| Merge em `main` | `<sha7>` + `latest` | Sim |
| Release `v1.2.3` | `1.2.3` + `latest` | Sim — tag semântica imutável |

Builds de PR não publicam imagem — o Trivy scan roda contra a imagem buildada localmente no runner.

---

## Estrutura do Helm chart

Um chart por microservice, em `deploy/<service-name>/`.

```text
deploy/
└── checkout-service/
    ├── Chart.yaml
    ├── values.yaml           # valores padrão (dev / homolog)
    ├── values-prod.yaml      # overrides de produção
    └── templates/
        ├── deployment.yaml
        ├── service.yaml
        ├── hpa.yaml
        ├── pdb.yaml
        ├── serviceaccount.yaml
        ├── networkpolicy.yaml
        └── externalsecret.yaml
```

### Chart.yaml

```yaml
apiVersion: v2
name: checkout-service
description: Gerencia checkouts e cotações de frete
type: application
version: 0.1.0          # versão do chart (semver)
appVersion: "1.0.0"     # versão do serviço — sobrescrita pelo pipeline com <sha>
```

### values.yaml (padrão)

```yaml
image:
  repository: 123456789.dkr.ecr.sa-east-1.amazonaws.com/checkout-service
  tag: latest
  pullPolicy: IfNotPresent

replicaCount: 2

resources:
  requests:
    cpu: 250m
    memory: 256Mi
  limits:
    cpu: 1000m
    memory: 512Mi

autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 10
  targetCPUUtilizationPercentage: 70

service:
  port: 8080

env:
  ASPNETCORE_ENVIRONMENT: Staging
  AWS_REGION: sa-east-1

secretsManagerPath: /logistica/staging/checkout-service
```

### values-prod.yaml (overrides)

```yaml
replicaCount: 3

autoscaling:
  minReplicas: 3
  maxReplicas: 10

env:
  ASPNETCORE_ENVIRONMENT: Production

secretsManagerPath: /logistica/prod/checkout-service
```

---

## Resource sizing por categoria de serviço

Todos os valores se referem a **produção**. Homologação usa 50% dos requests e sem limits.

| Categoria | Serviços | CPU Request | CPU Limit | Mem Request | Mem Limit |
|---|---|---|---|---|---|
| Caminho crítico síncrono | `checkout-service`, `shipping-promise-service`, `routing-service` | 250m | 1000m | 256Mi | 512Mi |
| Lookup com cache | `inventory-service`, `product-catalog-service`, `fulfillment-center-service` | 200m | 500m | 256Mi | 512Mi |
| Integração externa | `carrier-service`, `payment-service` | 200m | 500m | 256Mi | 512Mi |
| Consumer Kafka (assíncrono) | `notification-service`, `audit-service`, `tracking-service` | 100m | 500m | 128Mi | 256Mi |
| Saga / estado | `order-service`, `shipment-service` | 250m | 1000m | 256Mi | 512Mi |
| Cálculo de frete | `shipping-pricing-service` | 200m | 500m | 256Mi | 512Mi |
| BFF | `marketplace-web-bff` | 250m | 500m | 256Mi | 512Mi |

> Valores revisados trimestralmente com base em métricas de `process_cpu_usage` e `dotnet_gc_heap_size_bytes` do Grafana.

---

## Configuração do Pod

### Deployment template — checkout-service

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: checkout-service
  namespace: logistica-prod
spec:
  replicas: {{ .Values.replicaCount }}
  selector:
    matchLabels:
      app: checkout-service
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 0   # zero-downtime obrigatório
      maxSurge: 1
  template:
    metadata:
      labels:
        app: checkout-service
        version: {{ .Values.image.tag }}
    spec:
      serviceAccountName: checkout-service
      terminationGracePeriodSeconds: 60

      # Init container — garante que migrations rodaram antes do app subir
      initContainers:
        - name: db-migration
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
          command: ["dotnet", "CheckoutService.dll", "--migrate-only"]
          envFrom:
            - secretRef:
                name: checkout-service-secrets

      containers:
        - name: checkout-service
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
          ports:
            - containerPort: 8080
          envFrom:
            - configMapRef:
                name: checkout-service-config
            - secretRef:
                name: checkout-service-secrets
          resources:
            requests:
              cpu: {{ .Values.resources.requests.cpu }}
              memory: {{ .Values.resources.requests.memory }}
            limits:
              cpu: {{ .Values.resources.limits.cpu }}
              memory: {{ .Values.resources.limits.memory }}
          livenessProbe:
            httpGet:
              path: /health/live
              port: 8080
            initialDelaySeconds: 15
            periodSeconds: 10
            failureThreshold: 3
          readinessProbe:
            httpGet:
              path: /health/ready
              port: 8080
            initialDelaySeconds: 5
            periodSeconds: 5
            failureThreshold: 3

      # Distribuição entre zonas de disponibilidade
      topologySpreadConstraints:
        - maxSkew: 1
          topologyKey: topology.kubernetes.io/zone
          whenUnsatisfiable: DoNotSchedule
          labelSelector:
            matchLabels:
              app: checkout-service
        - maxSkew: 1
          topologyKey: kubernetes.io/hostname
          whenUnsatisfiable: ScheduleAnyway
          labelSelector:
            matchLabels:
              app: checkout-service
```

---

## PodDisruptionBudget

Garante que ao menos um pod permanece disponível durante drenagem de nó (node upgrade, spot reclaim).

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: checkout-service-pdb
  namespace: logistica-prod
spec:
  minAvailable: 1
  selector:
    matchLabels:
      app: checkout-service
```

Aplicado a **todos os serviços**. Para serviços com `minReplicas: 3` (caminho crítico), usar `minAvailable: 2`.

---

## Auto Scaling (HPA)

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: checkout-service-hpa
  namespace: logistica-prod
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: checkout-service
  minReplicas: {{ .Values.autoscaling.minReplicas }}
  maxReplicas: {{ .Values.autoscaling.maxReplicas }}
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300   # aguarda 5 min antes de reduzir pods
```

| Serviço | minReplicas | maxReplicas |
|---|---|---|
| `checkout-service` | 3 | 10 |
| `shipping-promise-service` | 3 | 10 |
| `routing-service` | 3 | 10 |
| `order-service` | 2 | 10 |
| `payment-service` | 2 | 10 |
| Demais serviços | 2 | 10 |

---

## Secrets e configuração

### External Secrets Operator

Segredos são gerenciados no **AWS Secrets Manager** e sincronizados para Kubernetes Secrets via [External Secrets Operator](https://external-secrets.io).

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: checkout-service-secrets
  namespace: logistica-prod
spec:
  refreshInterval: 5m
  secretStoreRef:
    name: aws-secretsmanager
    kind: ClusterSecretStore
  target:
    name: checkout-service-secrets
    creationPolicy: Owner
  dataFrom:
    - extract:
        key: /logistica/prod/checkout-service
```

O path `/logistica/prod/checkout-service` no Secrets Manager armazena um JSON com todos os segredos do serviço:

```json
{
  "ConnectionStrings__Default": "Host=...;Database=checkout;...",
  "Kafka__BootstrapServers": "...",
  "Redis__ConnectionString": "...",
  "MercadoPago__ApiKey": "..."
}
```

### IRSA — IAM Role for Service Account

Cada serviço tem seu próprio `ServiceAccount` com IAM Role via IRSA. Princípio de menor privilégio: cada role tem acesso apenas ao que o serviço precisa.

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: checkout-service
  namespace: logistica-prod
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::123456789:role/logistica-prod-checkout-service
```

Permissões mínimas da IAM Role (exemplo para `checkout-service`):

```json
{
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["secretsmanager:GetSecretValue"],
      "Resource": "arn:aws:secretsmanager:sa-east-1:123456789:secret:/logistica/prod/checkout-service-*"
    }
  ]
}
```

### ConfigMap — configuração não sensível

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: checkout-service-config
  namespace: logistica-prod
data:
  ASPNETCORE_ENVIRONMENT: "Production"
  AWS_REGION: "sa-east-1"
  Kafka__ConsumerGroupId: "checkout-service"
  Observability__OtlpEndpoint: "http://otel-collector.monitoring:4317"
```

---

## Network Policy

Por padrão, todos os namespaces têm política `deny-all`. Cada serviço declara explicitamente quais pods podem se comunicar com ele.

```yaml
# Nega todo ingress por padrão no namespace
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: logistica-prod
spec:
  podSelector: {}
  policyTypes: [Ingress]
---
# Permite apenas o que o checkout-service precisa receber
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: checkout-service-ingress
  namespace: logistica-prod
spec:
  podSelector:
    matchLabels:
      app: checkout-service
  policyTypes: [Ingress]
  ingress:
    - from:
        - podSelector:
            matchLabels:
              app: marketplace-web-bff      # única fonte de tráfego HTTP externo
      ports:
        - port: 8080
    - from:
        - namespaceSelector:
            matchLabels:
              name: monitoring              # Prometheus scrape
      ports:
        - port: 8080
```

---

## Init Container — migrations de banco

Antes do container da aplicação subir, um init container executa as migrations do Entity Framework Core:

```yaml
initContainers:
  - name: db-migration
    image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
    command: ["dotnet", "CheckoutService.dll", "--migrate-only"]
    envFrom:
      - secretRef:
          name: checkout-service-secrets
```

**Por que init container e não job separado?**  
O init container aborta o deploy caso a migration falhe, ativando o rollback automático do `--atomic`. Um job separado não bloqueia o Helm e permitiria o app subir contra um schema desatualizado.

---

## Rollback

O Helm deploy usa `--atomic`: se algum pod não atingir `Ready` dentro de 5 minutos, o release é revertido automaticamente para a revisão anterior.

```bash
# Pipeline — deploy com rollback automático
helm upgrade --install checkout-service ./deploy/checkout-service \
  -n logistica-prod \
  -f ./deploy/checkout-service/values-prod.yaml \
  --set image.tag=${IMAGE_TAG} \
  --atomic \
  --timeout 5m \
  --wait
```

Rollback manual:

```bash
# Ver histórico de releases
helm history checkout-service -n logistica-prod

# Reverter para a revisão anterior
helm rollback checkout-service 1 -n logistica-prod
```

---

## Checklist de release para produção

Executado pelo pipeline antes de acionar o `helm upgrade`:

| # | Verificação | Responsável |
|---|---|---|
| 1 | Todos os quality gates do CI passaram (build, testes, cobertura ≥ 80%, SonarCloud, CodeQL, Semgrep) | CI automático |
| 2 | Trivy scan: zero CVE `CRITICAL`/`HIGH` na imagem | CI automático |
| 3 | Imagem publicada no ECR com tag `<sha>` e `latest` | CI automático |
| 4 | PR revisado e aprovado por ao menos 1 reviewer | Review manual |
| 5 | Aprovação no GitHub Environment `production` | Tech Lead / Engineer on-call |
| 6 | Deploy em homologação concluído sem erros nas últimas 24h | CI automático |
| 7 | Smoke test em homologação: `POST /api/web/v1/shipping-promises` retorna `200` | CI automático |
| 8 | Deploy em produção via `helm upgrade --atomic` | CI automático |
| 9 | Health check: `GET /health/ready` retorna `200` em todos os pods | CI automático |
| 10 | Dashboard Grafana "SLO Compliance" sem alertas ativos por 5 min | Engineer on-call |

---

## Referências

- [CI/CD → docs/devops/ci-cd.md](ci-cd.md)
- [Ambientes → docs/devops/environments.md](environments.md)
- [Observabilidade → docs/devops/observability.md](observability.md)
- [Pipeline detalhado → docs/cicd/pipeline.md](../cicd/pipeline.md)
- [ADR-0003 — Hexagonal Clean Architecture](../adr/0003-hexagonal-clean-architecture.md)
