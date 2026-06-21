# ADR-0003 — Arquitetura Hexagonal e Clean Architecture em Microservices

## Status

Aceita

## Data

2026-06-20

## Contexto

Os microservices do case Logística Envios são implementados em .NET 8 com C#. A escolha de padrão arquitetural interno impacta testabilidade, manutenibilidade e capacidade de trocar dependências externas (banco de dados, broker, APIs de terceiros) sem modificar a lógica de negócio.

Padrões considerados:

- **Arquitetura em camadas tradicional**: Domain → Application → Infrastructure (dependência unidirecional para baixo).
- **Arquitetura hexagonal (Ports and Adapters)**: Domain no centro, Application orquestra, Infrastructure implementa as portas; dependências apontam para o interior.
- **CQRS com Event Sourcing**: separação de comandos e consultas com estado derivado de eventos; complexidade elevada.

## Decisão

Adotar **arquitetura hexagonal** (Ports and Adapters), também chamada de Clean Architecture, como padrão obrigatório em todos os microservices.

### Estrutura de projetos .NET obrigatória

```text
<ServiceName>/
├── <ServiceName>.Domain/          # Entidades, value objects, domain events, interfaces de porta (ex: IShipmentRepository)
├── <ServiceName>.Application/     # Use cases, application services, DTOs, interfaces de serviço de aplicação
├── <ServiceName>.Infrastructure/  # Implementações de repositórios, clients HTTP, publishers Kafka, DbContext
└── <ServiceName>.API/             # Controllers, middlewares, configuração DI, Program.cs
```

### Regras de dependência

```
API → Application → Domain
Infrastructure → Domain
API → Infrastructure (via DI)
```

- `Domain` não deve referenciar nenhum outro projeto do solution.
- `Application` não deve referenciar `Infrastructure` nem `API`.
- `Infrastructure` não deve referenciar `Application` nem `API`.
- Interfaces (portas) vivem em `Domain` ou `Application`; implementações (adaptadores) vivem em `Infrastructure`.

## Justificativa

| Critério | Camadas tradicional | Hexagonal |
|---|---|---|
| Testabilidade do domínio | Média (depende de infra) | Alta (domínio isolado) |
| Substituição de dependências | Difícil | Fácil via porta/adaptador |
| Clareza de boundaries | Baixa | Alta |
| Overhead inicial | Baixo | Médio |

Para um ecossistema com 13+ microservices e múltiplos agentes de IA gerando código, boundaries claros reduzem erros de acoplamento e facilitam geração de código correto.

## Consequências positivas

- Domínio testável sem dependência de banco, Kafka ou HTTP externo.
- Fácil substituição de implementações de infraestrutura (ex: trocar Postgres por outro banco).
- Agentes de IA com contexto claro de onde cada tipo de código deve viver.
- Facilita mock de portas em testes unitários.

## Consequências negativas

- Overhead de projetos/assemblies adicionais.
- Necessidade de mapeamento entre DTOs de Application e entidades de Domain.
- Curva de aprendizado para times acostumados com camadas tradicionais.

## Regras

1. Todo microservice DEVE ter os quatro projetos: `Domain`, `Application`, `Infrastructure`, `API`.
2. Interfaces de repositório e serviços externos DEVEM ser declaradas em `Domain` ou `Application`.
3. Implementações concretas (EF Core, Confluent.Kafka, HttpClient) DEVEM residir em `Infrastructure`.
4. Controllers DEVEM injetar interfaces de `Application`, nunca de `Infrastructure` diretamente.
5. Entidades de domínio NÃO DEVEM ter dependências de framework (EF Core data annotations no domínio são permitidas apenas como exceção documentada).
6. Use cases em `Application` DEVEM ser testados com mocks das portas de `Domain`.
