# ADR-0004 — Estratégia de Versionamento de Schemas Kafka

## Status

Aceita

## Data

2026-06-20

## Contexto

Os eventos Kafka canônicos do ecossistema Logística Envios usam um envelope padrão com campo `schemaVersion`. Com múltiplos producers e consumers desenvolvidos independentemente, é necessária uma estratégia clara para evoluir schemas sem quebrar integrações existentes.

Abordagens consideradas:

- **Schema Registry (Confluent/Apicurio)**: versionamento formal com compatibilidade enforçada no broker.
- **Versionamento semântico textual + processo manual**: sem ferramenta externa, governado por processo e revisão de PR.
- **Versionamento por nome de tópico** (ex: `order.created.v2`): cria proliferação de tópicos.

## Decisão

Adotar **versionamento semântico textual** via campo `schemaVersion` no envelope Kafka, governado por processo de PR e ADR, sem Schema Registry externo neste momento.

### Regras de versionamento

| Tipo de mudança | Impacto | Ação |
|---|---|---|
| Adição de campo opcional | Backward-compatible | Incrementar minor: `1.0` → `1.1` |
| Adição de campo obrigatório com default | Backward-compatible (com cuidado) | Incrementar minor: `1.0` → `1.1` |
| Remoção de campo | Breaking | Nova versão major: `1.x` → `2.0` + novo ADR |
| Renaming de campo | Breaking | Nova versão major: `1.x` → `2.0` + novo ADR |
| Mudança de tipo de campo | Breaking | Nova versão major: `1.x` → `2.0` + novo ADR |
| Mudança de semântica de campo | Breaking | Nova versão major: `1.x` → `2.0` + novo ADR |

### Processo de evolução

1. Criar PR com alteração no payload do `docs/contracts/kafka-events.md`.
2. Se mudança breaking: criar novo ADR **antes** de aplicar, com período de coexistência mínimo de 30 dias ou 2 deploys em produção.
3. Atualizar `schemaVersion` no envelope e na documentação do tópico.
4. Notificar owners dos consumers documentados (listados em `kafka-events.md`).
5. Período de coexistência: producer publica nova versão; consumers antigos continuam funcionando até migração.
6. Após migração de todos os consumers: deprecar versão antiga com data de remoção.

### Padrão Tolerant Reader (obrigatório)

Todo consumer Kafka DEVE ignorar campos desconhecidos no payload. Em .NET/C#:

```csharp
var options = new JsonSerializerOptions
{
    PropertyNameCaseInsensitive = true,
    // JsonSerializer ignora campos desconhecidos por padrão no .NET System.Text.Json
};
```

Ao usar Newtonsoft.Json:

```csharp
settings.MissingMemberHandling = MissingMemberHandling.Ignore;
```

## Justificativa

Um Schema Registry externo adiciona complexidade operacional significativa (deploy, manutenção, SLA) para um repositório de estudo e desenvolvimento local. O versionamento semântico textual + processo de PR e ADR oferece rastreabilidade suficiente para o estágio atual do projeto.

A adoção de Schema Registry formal (Confluent ou Apicurio) pode ser revisada quando o ecossistema atingir maturidade de produção — nesse momento, um novo ADR deve ser criado.

## Consequências positivas

- Sem dependência de infraestrutura adicional para desenvolvimento local.
- Rastreabilidade clara via git history e ADRs.
- Processo leve e adequado ao estágio atual do projeto.

## Consequências negativas

- Sem enforcement automático de compatibilidade no broker.
- Dependente de disciplina de processo e revisão de PR.
- Sem geração automática de código de serialização a partir de schema.

## Regras

1. Todo evento canônico DEVE conter o campo `schemaVersion` no envelope padrão.
2. Mudanças backward-compatible incrementam o minor version.
3. Mudanças breaking exigem ADR aprovado antes do deploy.
4. Todo consumer DEVE implementar o padrão Tolerant Reader.
5. O campo `schemaVersion` usa formato `<major>.<minor>` (ex: `"1.0"`, `"1.1"`, `"2.0"`).
6. A tabela de ownership em `docs/contracts/kafka-schema-governance.md` DEVE ser atualizada a cada mudança de schema.

## Decisões relacionadas

- [ADR-0001 — Usar arquitetura orientada a eventos](0001-use-event-driven-architecture.md)
