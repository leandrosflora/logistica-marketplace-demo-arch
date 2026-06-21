# Pipeline CI/CD — Logística Envios Microservices

## Visão geral

Este documento descreve o pipeline CI/CD esperado para todos os microservices do ecossistema Logística Envios implementados em .NET 8. O pipeline é executado automaticamente a cada push em branches de feature e em pull requests para `develop` e `main`.

---

## Etapas obrigatórias

| # | Etapa | Quando executa | Falha fatal |
|---|---|---|---|
| 1 | Build & Test (unit + integração) | Sempre | Sim |
| 2 | Coverage gate (≥ 80% linhas) | Sempre | Sim |
| 3 | Formatação (`dotnet format`) | Sempre | Sim |
| 4 | SonarCloud quality gate | Sempre | Sim |
| 5 | SAST — CodeQL + Semgrep | Sempre (paralelo) | Sim |
| 6 | Validate OpenAPI contract | Sempre | Sim |
| 7 | Container scan — Trivy | Push em `develop` / `main` | Sim — bloqueia push ECR |
| 8 | Build + Push ECR | Push em `develop` / `main` | Sim |
| 9 | Deploy Helm (homolog) | Push em `develop` | Sim |
| 10 | Deploy Helm (prod + approval) | Push em `main` | Sim |

### Regras

- Pipeline falha imediatamente se qualquer etapa obrigatória falhar (fail-fast por job).
- Testes de integração executam com Postgres e Kafka reais via `services` do GitHub Actions.
- Imagem Docker só é publicada no ECR após todos os gates de segurança passarem.
- Deploy de produção requer approval manual no GitHub Environments.
- Deploy usa `--atomic`: rollback automático se o pod não ficar `Ready` em 5 minutos.

---

## Template de workflow GitHub Actions para .NET 8

Copie e adapte para cada repositório de microservice. Substitua `<ServiceName>` pelo nome do serviço (ex: `OrderService`).

```yaml
name: CI/CD

on:
  push:
    branches:
      - main
      - develop
      - 'feature/**'
      - 'fix/**'
      - 'hotfix/**'
  pull_request:
    branches:
      - main
      - develop

env:
  DOTNET_VERSION: '8.0.x'
  SOLUTION_FILE: 'src/<ServiceName>.sln'
  ECR_REGION: us-east-1

jobs:

  # ──────────────────────────────────────────────────
  # 1. Build, Test, Coverage e SonarCloud
  # ──────────────────────────────────────────────────
  build-and-test:
    name: Build, Test & Analyze
    runs-on: ubuntu-latest

    services:
      postgres:
        image: postgres:16-alpine
        env:
          POSTGRES_DB: logistica_envios_test
          POSTGRES_USER: logistica
          POSTGRES_PASSWORD: logistica
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
          KAFKA_INTER_BROKER_LISTENER_NAME: PLAINTEXT
          KAFKA_CONTROLLER_LISTENER_NAMES: CONTROLLER
          KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR: 1
          KAFKA_AUTO_CREATE_TOPICS_ENABLE: 'true'
        ports:
          - 9092:9092

      redis:
        image: redis:7-alpine
        ports:
          - 6379:6379

    steps:
      - name: Checkout
        uses: actions/checkout@v4
        with:
          fetch-depth: 0   # SonarCloud precisa do histórico completo

      - name: Setup .NET
        uses: actions/setup-dotnet@v4
        with:
          dotnet-version: ${{ env.DOTNET_VERSION }}

      - name: Install dotnet-sonarscanner
        run: dotnet tool install --global dotnet-sonarscanner

      - name: SonarCloud — begin
        run: |
          dotnet sonarscanner begin \
            /k:"${{ secrets.SONAR_PROJECT_KEY }}" \
            /o:"${{ secrets.SONAR_ORGANIZATION }}" \
            /d:sonar.token="${{ secrets.SONAR_TOKEN }}" \
            /d:sonar.cs.opencover.reportsPaths="**/coverage.opencover.xml" \
            /d:sonar.qualitygate.wait=true
        env:
          SONAR_TOKEN: ${{ secrets.SONAR_TOKEN }}

      - name: Restore
        run: dotnet restore ${{ env.SOLUTION_FILE }}

      - name: Build
        run: dotnet build ${{ env.SOLUTION_FILE }} --no-restore --configuration Release

      - name: Test com cobertura
        run: |
          dotnet test ${{ env.SOLUTION_FILE }} \
            --no-build \
            --configuration Release \
            --verbosity normal \
            --logger "trx;LogFileName=test-results.xml" \
            /p:CollectCoverage=true \
            /p:CoverletOutputFormat=opencover \
            /p:Threshold=80 \
            /p:ThresholdType=line
        env:
          ConnectionStrings__Default: "Host=localhost;Port=5432;Database=logistica_envios_test;Username=logistica;Password=logistica"
          Kafka__BootstrapServers: "localhost:9092"
          Redis__ConnectionString: "localhost:6379"

      - name: Upload resultados de testes
        uses: actions/upload-artifact@v4
        if: always()
        with:
          name: test-results
          path: '**/test-results.xml'

      - name: SonarCloud — end
        run: dotnet sonarscanner end /d:sonar.token="${{ secrets.SONAR_TOKEN }}"
        env:
          SONAR_TOKEN: ${{ secrets.SONAR_TOKEN }}

      - name: Verificar formatação
        run: dotnet format ${{ env.SOLUTION_FILE }} --verify-no-changes

  # ──────────────────────────────────────────────────
  # 2. SAST — CodeQL + Semgrep (paralelo ao build)
  # ──────────────────────────────────────────────────
  sast:
    name: SAST (CodeQL + Semgrep)
    runs-on: ubuntu-latest
    permissions:
      security-events: write
      actions: read
      contents: read

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup .NET
        uses: actions/setup-dotnet@v4
        with:
          dotnet-version: ${{ env.DOTNET_VERSION }}

      - name: Inicializar CodeQL
        uses: github/codeql-action/init@v3
        with:
          languages: csharp
          queries: security-and-quality

      - name: Build para CodeQL
        run: dotnet build ${{ env.SOLUTION_FILE }} --configuration Release

      - name: Analisar com CodeQL
        uses: github/codeql-action/analyze@v3
        with:
          category: "/language:csharp"

      - name: Semgrep scan
        uses: semgrep/semgrep-action@v1
        with:
          config: >
            p/csharp
            p/owasp-top-ten
            p/secrets
        env:
          SEMGREP_APP_TOKEN: ${{ secrets.SEMGREP_APP_TOKEN }}

  # ──────────────────────────────────────────────────
  # 3. Validação de contrato OpenAPI
  # ──────────────────────────────────────────────────
  validate-contracts:
    name: Validate OpenAPI Contract
    runs-on: ubuntu-latest

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Validar sintaxe do OpenAPI YAML
        run: |
          docker run --rm \
            -v "$PWD:/work" \
            mikefarah/yq eval \
            /work/src/<ServiceName>.API/openapi.yaml

  # ──────────────────────────────────────────────────
  # 4. Container scan — Trivy (só em push para develop/main)
  # ──────────────────────────────────────────────────
  container-scan:
    name: Container Scan (Trivy)
    runs-on: ubuntu-latest
    needs: build-and-test
    if: github.ref == 'refs/heads/main' || github.ref == 'refs/heads/develop'

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Build imagem Docker para scan
        run: |
          docker build \
            -t ${{ github.event.repository.name }}:scan-${{ github.sha }} \
            --file src/<ServiceName>.API/Dockerfile \
            .

      - name: Scan com Trivy
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: ${{ github.event.repository.name }}:scan-${{ github.sha }}
          format: table
          severity: CRITICAL,HIGH
          exit-code: '1'
          ignore-unfixed: true

  # ──────────────────────────────────────────────────
  # 5. Build e Push para Amazon ECR (OIDC — sem credenciais longas)
  # ──────────────────────────────────────────────────
  push-ecr:
    name: Build & Push to ECR
    runs-on: ubuntu-latest
    needs: [build-and-test, sast, container-scan]
    if: github.ref == 'refs/heads/main' || github.ref == 'refs/heads/develop'
    permissions:
      id-token: write   # obrigatório para OIDC
      contents: read

    outputs:
      image_tag: ${{ steps.tags.outputs.sha_tag }}

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Configurar credenciais AWS (OIDC)
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_DEPLOY_ROLE_ARN }}
          aws-region: ${{ env.ECR_REGION }}

      - name: Login no Amazon ECR
        uses: aws-actions/amazon-ecr-login@v2

      - name: Calcular tags da imagem
        id: tags
        run: |
          BRANCH_SLUG=$(echo "${{ github.ref_name }}" | sed 's/[^a-zA-Z0-9]/-/g' | tr '[:upper:]' '[:lower:]')
          SHA_TAG="${{ secrets.ECR_REGISTRY }}/${{ github.event.repository.name }}:${{ github.sha }}"
          BRANCH_TAG="${{ secrets.ECR_REGISTRY }}/${{ github.event.repository.name }}:${BRANCH_SLUG}"
          echo "sha_tag=${SHA_TAG}" >> $GITHUB_OUTPUT
          echo "branch_tag=${BRANCH_TAG}" >> $GITHUB_OUTPUT

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Build e push
        uses: docker/build-push-action@v5
        with:
          context: .
          file: src/<ServiceName>.API/Dockerfile
          push: true
          tags: |
            ${{ steps.tags.outputs.sha_tag }}
            ${{ steps.tags.outputs.branch_tag }}
          cache-from: type=gha
          cache-to: type=gha,mode=max

  # ──────────────────────────────────────────────────
  # 6. Deploy em Homologação (automático em push para develop)
  # ──────────────────────────────────────────────────
  deploy-homolog:
    name: Deploy → Homologação
    runs-on: ubuntu-latest
    needs: push-ecr
    if: github.ref == 'refs/heads/develop'
    environment: homologation
    permissions:
      id-token: write
      contents: read

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Configurar credenciais AWS (OIDC)
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_DEPLOY_ROLE_ARN }}
          aws-region: ${{ env.ECR_REGION }}

      - name: Atualizar kubeconfig EKS Homolog
        run: aws eks update-kubeconfig --name logistica-homolog --region ${{ env.ECR_REGION }}

      - name: Helm upgrade (homolog)
        run: |
          helm upgrade --install ${{ github.event.repository.name }} \
            ./deploy/${{ github.event.repository.name }} \
            --namespace logistica-homolog \
            --create-namespace \
            --set image.repository=${{ secrets.ECR_REGISTRY }}/${{ github.event.repository.name }} \
            --set image.tag=${{ github.sha }} \
            --set environment=homologation \
            --wait \
            --timeout 5m \
            --atomic

      - name: Verificar health do deploy
        run: |
          kubectl rollout status deployment/${{ github.event.repository.name }} \
            -n logistica-homolog \
            --timeout=300s

  # ──────────────────────────────────────────────────
  # 7. Deploy em Produção (approval obrigatório)
  # ──────────────────────────────────────────────────
  deploy-prod:
    name: Deploy → Produção
    runs-on: ubuntu-latest
    needs: push-ecr
    if: github.ref == 'refs/heads/main'
    environment:
      name: production
      url: https://logistica.example.com
    permissions:
      id-token: write
      contents: read

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Configurar credenciais AWS (OIDC)
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_DEPLOY_ROLE_ARN }}
          aws-region: ${{ env.ECR_REGION }}

      - name: Atualizar kubeconfig EKS Prod
        run: aws eks update-kubeconfig --name logistica-prod --region ${{ env.ECR_REGION }}

      - name: Helm upgrade (prod — atomic com rollback automático)
        run: |
          helm upgrade --install ${{ github.event.repository.name }} \
            ./deploy/${{ github.event.repository.name }} \
            --namespace logistica-prod \
            --create-namespace \
            --set image.repository=${{ secrets.ECR_REGISTRY }}/${{ github.event.repository.name }} \
            --set image.tag=${{ github.sha }} \
            --set environment=production \
            --wait \
            --timeout 5m \
            --atomic

      - name: Verificar health do deploy
        run: |
          kubectl rollout status deployment/${{ github.event.repository.name }} \
            -n logistica-prod \
            --timeout=300s
```

---

## Validação de contratos (repositório de arquitetura)

Os workflows abaixo estão configurados no repositório `logistica-envios-architecture` e são executados automaticamente.

### Render de diagramas PlantUML (GitHub Actions)

Workflow: `.github/workflows/render-diagrams.yml`

- **PR em `.puml`**: valida que os SVGs estão atualizados (falha se SVG divergir do `.puml`).
- **Push em `main`**: renderiza e commita os SVGs automaticamente.

### Comandos manuais equivalentes

```bash
# Validar sintaxe do OpenAPI
docker run --rm -v "$PWD:/work" mikefarah/yq eval docs/contracts/logistica-envios-apis.openapi.yaml

# Validar sintaxe dos .puml
docker run --rm -v "$PWD:/work" plantuml/plantuml \
  -checkmetadata /work/docs/c4/*.puml /work/docs/sequence-diagrams/*.puml

# Gerar SVGs localmente
docker run --rm -v "$PWD:/work" plantuml/plantuml \
  -tsvg /work/docs/c4/*.puml /work/docs/sequence-diagrams/*.puml
```

---

## Secrets necessários por repositório de microservice

| Secret | Escopo | Descrição |
|---|---|---|
| `AWS_DEPLOY_ROLE_ARN` | Repositório | ARN da IAM Role assumida via OIDC — sem credenciais longas |
| `ECR_REGISTRY` | Organização | URL do Amazon ECR (`<account>.dkr.ecr.<region>.amazonaws.com`) |
| `SONAR_TOKEN` | Repositório | Token de autenticação do SonarCloud |
| `SONAR_ORGANIZATION` | Organização | Slug da organização no SonarCloud |
| `SONAR_PROJECT_KEY` | Repositório | Chave do projeto no SonarCloud (ex: `logistica-order-service`) |
| `SEMGREP_APP_TOKEN` | Repositório | Token Semgrep App — opcional, sem token roda em modo OSS |

Credenciais de banco, Kafka e Redis usadas em testes de integração são valores locais fixos definidos nos `services` do workflow. **Nunca usar credenciais de produção em pipelines de CI.**

---

## Referências

- [Visão geral CI/CD → docs/devops/ci-cd.md](../devops/ci-cd.md)
- [Ambientes → docs/devops/environments.md](../devops/environments.md)
- [AGENTS.md](../../AGENTS.md)
- [ADR-0003 — Hexagonal Clean Architecture](../adr/0003-hexagonal-clean-architecture.md)
- [ADR-0006 — Stack de Observabilidade](../adr/0006-observability-stack.md)
