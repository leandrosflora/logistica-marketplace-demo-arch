# CI/CD — Logística Envios

## Objetivo

Garantir entrega contínua com gates automatizados de build, teste, segurança e deploy em todos os microservices do ecossistema.

---

## Fluxo de branches

```text
feature/* ──► develop ──► main
                │              │
           [homolog]       [produção]
```

| Branch | Trigger | Ambiente alvo |
|---|---|---|
| `feature/*`, `fix/*`, `hotfix/*` | PR para `develop` | Apenas CI — sem deploy |
| `develop` | Merge de PR aprovado | Homologação (EKS staging) |
| `main` | Merge de PR + approval manual | Produção (EKS prod) |

---

## Estágios do pipeline

```text
PR / push em feature
  ├─ 1. Build & Test       unit + integração (Postgres + Kafka via services)
  ├─ 2. Coverage gate      threshold ≥ 80% de linhas — falha fatal
  ├─ 3. Formatação         dotnet format --verify-no-changes
  ├─ 4. SonarCloud         quality gate: coverage + duplicações + code smells
  ├─ 5. SAST               CodeQL (C#) + Semgrep (OWASP top-10) — paralelos
  ├─ 6. Dependency scan    OWASP Dependency-Check + Dependabot alerts
  └─ 7. Contract validation  yq validate OpenAPI YAML

Merge em develop / main
  ├─ (todos os estágios acima)
  ├─ 8. Container scan     Trivy — CRITICAL/HIGH bloqueia push
  ├─ 9. Build + Push ECR   tag <sha> + <branch-slug> via OIDC IAM Role
  └─ 10. Deploy Helm       homolog → automático | prod → approval obrigatório
```

---

## Quality gates

| Gate | Critério | Bloqueia o merge? |
|---|---|---|
| Build | Zero erros de compilação | Sim |
| Testes | 100% dos testes passando | Sim |
| Cobertura | ≥ 80% de linhas cobertas | Sim |
| Formatação | `dotnet format` sem diff | Sim |
| SonarCloud | Quality Gate com status `Passed` | Sim |
| CodeQL | Zero findings `CRITICAL`/`HIGH` | Sim |
| Semgrep | Zero findings `CRITICAL`/`HIGH` | Sim |
| OWASP Dependency-Check | Zero CVE `CRITICAL` | Sim |
| Trivy (container) | Zero CVE `CRITICAL`/`HIGH` | Sim — bloqueia push para ECR |

---

## Secrets necessários

| Secret | Escopo | Descrição |
|---|---|---|
| `AWS_DEPLOY_ROLE_ARN` | Repositório | ARN da IAM Role usada via OIDC para push ECR e Helm deploy |
| `ECR_REGISTRY` | Organização | URL do Amazon ECR (`<account>.dkr.ecr.<region>.amazonaws.com`) |
| `SONAR_TOKEN` | Repositório | Token de autenticação do SonarCloud |
| `SONAR_ORGANIZATION` | Organização | Slug da organização no SonarCloud |
| `SONAR_PROJECT_KEY` | Repositório | Chave do projeto no SonarCloud (ex: `logistica-order-service`) |
| `SEMGREP_APP_TOKEN` | Repositório | Token de autenticação do Semgrep App (opcional — sem token roda em modo OSS) |

Credenciais de banco, Kafka e Redis para testes de integração são valores fixos locais definidos nos `services` do workflow. **Nunca usar credenciais de staging ou produção em pipelines de CI.**

---

## Versionamento de imagem Docker

| Contexto | Tag gerada |
|---|---|
| PR / feature | Não publicada no ECR externo |
| Merge em `develop` | `develop-<sha>` |
| Merge em `main` | `<sha>` + `latest` |
| Release tag `v1.2.3` | `1.2.3` + `latest` |

---

## Rollback

O Helm deploy usa `--atomic`: se o pod não ficar `Ready` em 5 minutos, o release é revertido automaticamente para a revisão anterior.

Rollback manual:

```bash
# Ver histórico de releases
helm history <service-name> -n logistica-prod

# Reverter para a revisão anterior
helm rollback <service-name> 1 -n logistica-prod
```

---

## Referências

- [Workflow YAML completo → docs/cicd/pipeline.md](../cicd/pipeline.md)
- [Ambientes → docs/devops/environments.md](environments.md)
- [Segurança → docs/devops/security.md](security.md)
- [ADR-0003 — Hexagonal Clean Architecture](../adr/0003-hexagonal-clean-architecture.md)
- [ADR-0006 — Stack de Observabilidade](../adr/0006-observability-stack.md)
