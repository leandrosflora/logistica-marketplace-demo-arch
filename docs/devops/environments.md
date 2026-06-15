# Environments

## Objetivo
Padronizar ambientes, fluxo de deploy e requisitos mínimos.

## Development
Docker Compose com Postgres/Redis/Kafka local. Branch `feature/*`. CI: build + testes + scans.

## Homologation (QA)
Amazon EKS pequeno + Amazon RDS (db.t4g.medium). Deploy automático do branch `develop`.

## Production
Amazon EKS multi-AZ + Amazon RDS (db.r7g.large) + Amazon MSK. Secrets no AWS Secrets Manager. Auto Scaling e backups.

## Sizing baseline
- Dev barato: EC2 t3.large rodando compose
- Homolog: EKS 2 nodes m7i.large
- Prod inicial: EKS 3 nodes m7i.large, HPA para 2-10 pods por serviço
