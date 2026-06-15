# Deployment Strategy

## Objetivo

Automatizar a entrega dos microservices utilizando containers e Kubernetes.

---

# Container Registry

Amazon ECR

Imagem por serviço.

Exemplo:

```text
auth-service
checkout-service
inventory-service
pricing-service
shipment-service
```

---

# Versionamento

Semantic Versioning.

Formato:

```text
v1.0.0
v1.1.0
v1.1.1
```

---

# Kubernetes

Deploy via Helm.

Estrutura:

```text
deploy/
├── checkout
├── inventory
├── pricing
├── shipment
└── order
```

---

# Rolling Update

```yaml
strategy:
  type: RollingUpdate
```

---

# Health Checks

Liveness:

```text
/health/live
```

Readiness:

```text
/health/ready
```

---

# Auto Scaling

HPA

```yaml
minReplicas: 2
maxReplicas: 10
```

---

# Release Process

1. Merge em main
2. Build
3. Tests
4. Security Scan
5. Docker Build
6. Push ECR
7. Helm Upgrade
8. Health Check
9. Release concluída
