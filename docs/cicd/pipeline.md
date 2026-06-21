# Pipeline CI/CD — Meli Envios Microservices

## Visão geral

Este documento descreve o pipeline CI/CD esperado para todos os microservices do ecossistema Meli Envios implementados em .NET 8. O pipeline é executado automaticamente a cada push em branches de feature e em pull requests para `main`.

---

## Etapas obrigatórias (em ordem)

| Etapa | Comando | Falha fatal |
|---|---|---|
| 1. Restore | `dotnet restore` | Sim |
| 2. Build | `dotnet build --no-restore --configuration Release` | Sim |
| 3. Testes | `dotnet test --no-build --verbosity normal --configuration Release` | Sim |
| 4. Formatação | `dotnet format --verify-no-changes` | Sim |
| 5. Validar OpenAPI | `docker run ... mikefarah/yq eval <openapi.yaml>` | Sim (se OpenAPI presente) |
| 6. Validar PlantUML | Executado no repo de arquitetura | Não (warning) |
| 7. Build Docker | `docker build -t <service>:<version> .` | Sim |
| 8. Push Docker | `docker push <registry>/<service>:<version>` | Sim (somente em merge para main) |

### Regras

- O pipeline DEVE falhar se qualquer etapa obrigatória falhar (fail-fast).
- Testes de integração com banco/Kafka devem ser executados com Docker Compose (não apenas testes unitários).
- Imagem Docker só é publicada no merge para `main` (não em PRs).
- Versão da imagem: `<major>.<minor>.<patch>` derivada do git tag ou `<branch>-<sha>` para builds de feature.

---

## Template de workflow GitHub Actions para .NET 8

Copie e adapte este template para cada repositório de microservice:

```yaml
name: CI

on:
  push:
    branches:
      - main
      - 'feature/**'
      - 'fix/**'
  pull_request:
    branches:
      - main

env:
  DOTNET_VERSION: '8.0.x'
  SOLUTION_FILE: 'src/<ServiceName>.sln'

jobs:
  build-and-test:
    name: Build, Test & Format
    runs-on: ubuntu-latest

    services:
      postgres:
        image: postgres:16-alpine
        env:
          POSTGRES_DB: meli_envios_test
          POSTGRES_USER: meli
          POSTGRES_PASSWORD: meli
        ports:
          - 5432:5432
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5

      kafka:
        image: confluentinc/cp-kafka:7.6.1
        env:
          CLUSTER_ID: MkU3OEVBNTcwNTJENDM2Qk
          KAFKA_NODE_ID: 1
          KAFKA_PROCESS_ROLES: broker,controller
          KAFKA_CONTROLLER_QUORUM_VOTERS: 1@localhost:29093
          KAFKA_LISTENERS: PLAINTEXT://localhost:29092,CONTROLLER://localhost:29093,PLAINTEXT_HOST://0.0.0.0:9092
          KAFKA_ADVERTISED_LISTENERS: PLAINTEXT://localhost:29092,PLAINTEXT_HOST://localhost:9092
          KAFKA_LISTENER_SECURITY_PROTOCOL_MAP: CONTROLLER:PLAINTEXT,PLAINTEXT:PLAINTEXT,PLAINTEXT_HOST:PLAINTEXT
          KAFKA_AUTO_CREATE_TOPICS_ENABLE: "true"
        ports:
          - 9092:9092

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup .NET
        uses: actions/setup-dotnet@v4
        with:
          dotnet-version: ${{ env.DOTNET_VERSION }}

      - name: Restore dependencies
        run: dotnet restore ${{ env.SOLUTION_FILE }}

      - name: Build
        run: dotnet build ${{ env.SOLUTION_FILE }} --no-restore --configuration Release

      - name: Run tests
        run: dotnet test ${{ env.SOLUTION_FILE }} --no-build --configuration Release --verbosity normal --logger "trx;LogFileName=test-results.xml"

      - name: Upload test results
        uses: actions/upload-artifact@v4
        if: always()
        with:
          name: test-results
          path: '**/test-results.xml'

      - name: Check formatting
        run: dotnet format ${{ env.SOLUTION_FILE }} --verify-no-changes

  validate-contracts:
    name: Validate Contracts
    runs-on: ubuntu-latest
    if: contains(github.event.head_commit.modified, 'docs/') || contains(github.event.head_commit.modified, 'openapi')

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Validate OpenAPI YAML
        run: |
          if ls src/**/*.openapi.yaml 1> /dev/null 2>&1; then
            docker run --rm -v "$PWD:/work" mikefarah/yq eval src/**/*.openapi.yaml
          fi

  docker-build:
    name: Docker Build & Push
    runs-on: ubuntu-latest
    needs: [build-and-test]
    if: github.ref == 'refs/heads/main'

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Login to Container Registry
        uses: docker/login-action@v3
        with:
          registry: ${{ secrets.REGISTRY_URL }}
          username: ${{ secrets.REGISTRY_USERNAME }}
          password: ${{ secrets.REGISTRY_PASSWORD }}

      - name: Build and push
        uses: docker/build-push-action@v5
        with:
          context: .
          push: true
          tags: ${{ secrets.REGISTRY_URL }}/<service-name>:${{ github.sha }}
```

---

## Validação de contratos (repositório de arquitetura)

Para validar os contratos OpenAPI e os diagramas PlantUML do repositório `meli-envios-architecture`:

### Validar OpenAPI

```bash
docker run --rm -v "$PWD:/work" mikefarah/yq eval docs/contracts/meli-envios-apis.openapi.yaml
```

### Validar PlantUML (sintaxe)

```bash
docker run --rm -v "$PWD:/work" plantuml/plantuml -checkmetadata /work/docs/c4/*.puml /work/docs/sequence-diagrams/*.puml
```

### Gerar SVGs dos diagramas

```bash
docker run --rm -v "$PWD:/work" plantuml/plantuml -tsvg /work/docs/c4/*.puml /work/docs/sequence-diagrams/*.puml
```

---

## Convenções de versionamento de imagem Docker

| Contexto | Tag |
|---|---|
| Merge em main | `latest` + `<sha>` |
| Release tag `v1.2.3` | `1.2.3` + `latest` |
| Feature branch | `feature-<branch-slug>-<sha>` (não publicado no registry externo) |

---

## Segredos necessários no repositório GitHub

| Secret | Descrição |
|---|---|
| `REGISTRY_URL` | URL do registry de imagens Docker |
| `REGISTRY_USERNAME` | Usuário do registry |
| `REGISTRY_PASSWORD` | Senha/token do registry |

Segredos de banco, Kafka e Redis para testes de integração são configurados nos `services` do workflow (valores locais de teste, nunca de produção).

---

## Referências

- [AGENTS.md](../../AGENTS.md) — comandos de validação obrigatórios
- [ADR-0003 — Arquitetura Hexagonal](../adr/0003-hexagonal-clean-architecture.md)
- [ADR-0006 — Stack de Observabilidade](../adr/0006-observability-stack.md)
