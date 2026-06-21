## ADDED Requirements

### Requirement: Documentação de autenticação e autorização entre serviços
O repositório SHALL conter um arquivo `docs/security/security-architecture.md` documentando a estratégia de autenticação e autorização adotada no ecossistema Meli Envios.

#### Scenario: Documento de segurança descreve autenticação
- **WHEN** o arquivo `docs/security/security-architecture.md` é lido
- **THEN** ele MUST descrever o mecanismo de autenticação (JWT/OAuth2 ou equivalente) usado pelo BFF e pelos microservices
- **THEN** ele MUST especificar onde tokens são validados (gateway, cada serviço, ou ambos)
- **THEN** ele MUST especificar o formato e claims obrigatórios do token (`buyerId`, `sellerId`, `clientId`, `scope`)

#### Scenario: Documento descreve propagação de identidade
- **WHEN** o arquivo `docs/security/security-architecture.md` é lido
- **THEN** ele MUST documentar que `x-correlation-id` DEVE ser propagado em todas as chamadas síncronas e eventos Kafka
- **THEN** ele MUST documentar que `x-client-id` DEVE ser propagado por BFFs consumidores
- **THEN** ele MUST documentar que `x-idempotency-key` DEVE ser exigido por endpoints de comando (POST, PUT)
- **THEN** ele MUST documentar como `correlationId` flui de APIs REST para eventos Kafka e de volta

#### Requirement: Documento descreve gestão de segredos
O arquivo `docs/security/security-architecture.md` SHALL descrever como segredos (connection strings, credenciais de Kafka, chaves de API) devem ser gerenciados em ambiente local e produção.

#### Scenario: Gestão de segredos documentada
- **WHEN** o arquivo `docs/security/security-architecture.md` é lido
- **THEN** ele MUST especificar que segredos NUNCA devem ser commitados no repositório
- **THEN** ele MUST especificar o mecanismo de gestão de segredos recomendado (ex: Azure Key Vault, HashiCorp Vault, User Secrets para desenvolvimento local)
- **THEN** ele MUST listar os segredos críticos do ecossistema (bootstrap Kafka, connection string Postgres, Redis password)
