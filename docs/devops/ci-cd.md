# CI/CD

## Objetivo
Garantir entrega continua com gates de qualidade e seguranca para os microservices do projeto.

## Pipeline (PR)
```
PR
  -> dotnet restore
  -> dotnet build
  -> dotnet test + cobertura
  -> SonarCloud (quality gate)
  -> CodeQL
  -> Semgrep
  -> Trivy (imagem)
  -> Build/push Docker para Amazon ECR
```

## Comandos (base)
- `dotnet restore`
- `dotnet build`
- `dotnet test /p:CollectCoverage=true /p:CoverletOutputFormat=opencover`

## Branch strategy
- `main` -> producao
- `develop` -> homolog
- `feature/*` -> desenvolvimento
- `hotfix/*` -> correcoes
