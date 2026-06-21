## ADDED Requirements

### Requirement: Specs individuais de microservice criadas
O repositório SHALL conter um arquivo de spec por microservice em `docs/services/<nome>-service.md` para todos os 13 serviços listados no README.

#### Scenario: Cada arquivo de spec existe para todos os serviços
- **WHEN** o diretório `docs/services/` é listado
- **THEN** ele MUST conter um arquivo para cada um dos seguintes serviços: `checkout-service.md`, `shipping-promise-service.md`, `product-catalog-service.md`, `product-search-service.md`, `inventory-service.md`, `fulfillment-center-service.md`, `routing-service.md`, `carrier-service.md`, `shipping-pricing-service.md`, `order-service.md`, `shipment-service.md`, `tracking-service.md`, `notification-service.md`, `audit-service.md`

### Requirement: Cada spec de serviço contém seções obrigatórias
Cada arquivo em `docs/services/` SHALL conter as seções: Responsabilidade, Dados dominados, APIs publicadas, Eventos Kafka publicados, Eventos Kafka consumidos, Dependências síncronas, SLOs, Regras de negócio principais, Decisões arquiteturais relacionadas.

#### Scenario: Seções obrigatórias presentes em cada spec
- **WHEN** um arquivo de spec de serviço é lido
- **THEN** ele MUST conter a seção "Responsabilidade" com descrição em 1-3 frases
- **THEN** ele MUST conter a seção "Dados dominados" com lista dos agregados/entidades que o serviço é o owner
- **THEN** ele MUST conter a seção "APIs publicadas" com lista de endpoints e método HTTP
- **THEN** ele MUST conter a seção "Eventos Kafka publicados" com referência ao tópico canônico e link para `kafka-events.md`
- **THEN** ele MUST conter a seção "Eventos Kafka consumidos" com referência ao tópico e consumer group
- **THEN** ele MUST conter a seção "Dependências síncronas" com lista de serviços chamados via HTTP
- **THEN** ele MUST conter a seção "SLOs" com metas de disponibilidade e latência (pode ser TBD inicialmente)
- **THEN** ele MUST conter a seção "Regras de negócio principais" com lista numerada das invariantes do serviço

### Requirement: Specs de serviço referenciadas no README e AGENTS.md
As specs individuais de serviço SHALL ser referenciadas no README principal e no AGENTS.md para que agentes de IA as consultem antes de implementar funcionalidades.

#### Scenario: README lista o diretório docs/services
- **WHEN** o `README.md` é lido
- **THEN** ele MUST conter referência ao diretório `docs/services/` na seção Estrutura e uma entrada na seção Microservices principais com link para o arquivo de spec correspondente

#### Scenario: AGENTS.md instrui leitura de specs de serviço
- **WHEN** o `AGENTS.md` é lido
- **THEN** ele MUST conter instrução para que agentes leiam `docs/services/<nome>-service.md` antes de gerar código para o serviço correspondente
