## ADDED Requirements

### Requirement: Documento de schema governance Kafka criado
O repositório SHALL conter o arquivo `docs/contracts/kafka-schema-governance.md` documentando o processo de evolução e governança de schemas dos eventos Kafka canônicos.

#### Scenario: Documento de governance criado com regras de versionamento
- **WHEN** o arquivo `docs/contracts/kafka-schema-governance.md` é lido
- **THEN** ele MUST definir os tipos de mudança backward-compatible (adição de campo opcional, novo tópico) e breaking (remoção, renaming, mudança de tipo, mudança de semântica)
- **THEN** ele MUST especificar que mudanças backward-compatible incrementam minor version do campo `schemaVersion` (ex: `1.0` → `1.1`)
- **THEN** ele MUST especificar que mudanças breaking exigem nova versão major e obrigatoriamente um novo ADR antes de aplicar

#### Scenario: Processo de evolução de contrato documentado
- **WHEN** o arquivo `docs/contracts/kafka-schema-governance.md` é lido
- **THEN** ele MUST descrever o processo: 1) criar PR com mudança no payload do `kafka-events.md`, 2) se breaking: criar ADR, 3) atualizar `schemaVersion` no envelope, 4) notificar owners dos consumers, 5) período de coexistência de versões
- **THEN** ele MUST especificar o período mínimo de coexistência de versões de schema (sugestão: 30 dias ou 2 deploys)

### Requirement: Tolerant reader pattern documentado como obrigatório
O documento de governance SHALL especificar que todos os consumers Kafka DEVEM implementar o padrão Tolerant Reader.

#### Scenario: Regra tolerant reader documentada
- **WHEN** o documento de governance é lido
- **THEN** ele MUST conter a regra: "Todo consumer DEVE ignorar campos desconhecidos no payload (tolerant reader pattern). A ausência dessa propriedade pode causar falhas na evolução backward-compatible de schemas."
- **THEN** ele MUST ser referenciado no `AGENTS.md` como leitura obrigatória ao implementar consumers Kafka

### Requirement: Ownership de tópicos documentado
O arquivo `docs/contracts/kafka-schema-governance.md` SHALL conter uma tabela de ownership por tópico canônico, identificando o serviço responsável pela evolução de cada schema.

#### Scenario: Tabela de ownership presente
- **WHEN** o documento de governance é lido
- **THEN** ele MUST conter tabela com colunas: Tópico, Owner do Schema, Service Producer, Consumers, Versão atual
- **THEN** a tabela MUST cobrir todos os 5 tópicos canônicos documentados em `kafka-events.md`
