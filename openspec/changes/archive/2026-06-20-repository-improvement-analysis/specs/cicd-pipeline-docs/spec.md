## ADDED Requirements

### Requirement: Documentação de pipeline CI/CD criada para microservices .NET 8
O repositório SHALL conter o arquivo `docs/cicd/pipeline.md` documentando o pipeline CI/CD esperado para todos os microservices do ecossistema Meli Envios.

#### Scenario: Pipeline document descreve etapas obrigatórias
- **WHEN** o arquivo `docs/cicd/pipeline.md` é lido
- **THEN** ele MUST descrever as etapas obrigatórias na seguinte ordem: 1) `dotnet restore`, 2) `dotnet build --no-restore`, 3) `dotnet test --no-build --verbosity normal`, 4) `dotnet format --verify-no-changes`, 5) validação de contratos (YAML/OpenAPI), 6) build da imagem Docker, 7) push da imagem para registry
- **THEN** ele MUST especificar que o pipeline DEVE falhar se qualquer etapa falhar (fail-fast)
- **THEN** ele MUST especificar que testes de integração com banco/Kafka são executados em ambiente com Docker Compose (não apenas unit tests)

#### Scenario: Pipeline descreve gatilhos e branches
- **WHEN** o arquivo `docs/cicd/pipeline.md` é lido
- **THEN** ele MUST especificar os gatilhos de CI: push em feature branches e PRs para `main`
- **THEN** ele MUST especificar que merge em `main` aciona CI completo + build de imagem Docker + deploy para ambiente de staging

### Requirement: Template de workflow GitHub Actions documentado
O arquivo `docs/cicd/pipeline.md` SHALL conter um template de workflow GitHub Actions (YAML) reutilizável para microservices .NET 8.

#### Scenario: Template GitHub Actions presente
- **WHEN** o arquivo `docs/cicd/pipeline.md` é lido
- **THEN** ele MUST conter um bloco de código YAML com workflow GitHub Actions cobrindo: checkout do código, setup do .NET 8 SDK, restore, build, test, format check
- **THEN** o template MUST conter variáveis de configuração para: nome do projeto, versão do .NET SDK, caminho do solution file

### Requirement: Validação de contratos incluída no pipeline
O pipeline CI/CD SHALL incluir etapa de validação dos contratos OpenAPI e dos arquivos PlantUML.

#### Scenario: Validação de contratos no pipeline
- **WHEN** o arquivo `docs/cicd/pipeline.md` é lido
- **THEN** ele MUST documentar o comando Docker para validação de YAML OpenAPI: `docker run --rm -v "$PWD:/work" mikefarah/yq eval <arquivo>.openapi.yaml`
- **THEN** ele MUST documentar o comando Docker para validação de PlantUML: `docker run --rm -v "$PWD:/work" plantuml/plantuml -checkmetadata /work/docs/c4/*.puml`
