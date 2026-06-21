# Deployment Strategy

## Objetivo

Automatizar a entrega dos microservices utilizando containers e Kubernetes.

---

## Container Registry

Amazon ECR. Uma imagem por microservice.

```text
checkout-service
shipping-promise-service
product-catalog-service
product-search-service
inventory-service
fulfillment-center-service
routing-service
carrier-service
shipping-pricing-service
order-service
shipment-service
tracking-service
notification-service
audit-service
marketplace-web-bff
```

---

## Versionamento

Semantic Versioning.

```text
v1.0.0
v1.1.0
v1.1.1
```

---

## Kubernetes

Deploy via Helm. Um chart por microservice.

```text
deploy/
├── checkout-service/
├── shipping-promise-service/
├── product-catalog-service/
├── product-search-service/
├── inventory-service/
├── fulfillment-center-service/
├── routing-service/
├── carrier-service/
├── shipping-pricing-service/
├── order-service/
├── shipment-service/
├── tracking-service/
├── notification-service/
├── audit-service/
└── marketplace-web-bff/
```

---

## Rolling Update

```yaml
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxUnavailable: 0
    maxSurge: 1
```

---

## Health Checks

```yaml
livenessProbe:
  httpGet:
    path: /health/live
    port: 80
  initialDelaySeconds: 10
  periodSeconds: 10

readinessProbe:
  httpGet:
    path: /health/ready
    port: 80
  initialDelaySeconds: 5
  periodSeconds: 5
```

---

## Auto Scaling (HPA)

```yaml
minReplicas: 2
maxReplicas: 10
metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
```

Serviços no caminho crítico de cotação (`shipping-promise-service`, `checkout-service`, `routing-service`) devem ter `minReplicas: 3`.

---

## Release Process

1. Merge em `main`
2. CI: build + testes + scans de segurança
3. Docker Build + Push ECR (tag: `<sha>` + `latest`)
4. Approval manual no GitHub Environments (`production`)
5. Helm upgrade `--atomic` no EKS prod
6. Health check automático (`/health/ready`)
7. Rollback automático se health check falhar em 5 minutos

---

## Referências

- [CI/CD → docs/devops/ci-cd.md](ci-cd.md)
- [Ambientes → docs/devops/environments.md](environments.md)
- [Pipeline detalhado → docs/cicd/pipeline.md](../cicd/pipeline.md)
