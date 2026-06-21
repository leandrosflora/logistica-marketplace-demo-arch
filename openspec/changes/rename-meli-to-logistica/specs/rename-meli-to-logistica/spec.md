## ADDED Requirements

### Requirement: Consistência de prefixo no repositório
Todo artefato do repositório deve usar o prefixo `logistica-envios` (kebab-case) ou `logistica_envios` (snake_case) e o texto display `Logística Envios` — nunca `meli-envios`, `meli_envios` ou `Meli Envios`.

#### Scenario: Nome de arquivo contém "meli"
- **WHEN** um arquivo tem `meli-envios` ou `meli_envios` no nome
- **THEN** o arquivo deve ser renomeado substituindo o prefixo por `logistica-envios` ou `logistica_envios`

#### Scenario: Conteúdo de arquivo referencia "meli-envios"
- **WHEN** o conteúdo de um `.md`, `.puml`, `.yaml` ou `.yml` contém a string `meli-envios`
- **THEN** a string deve ser substituída por `logistica-envios`

#### Scenario: Conteúdo de arquivo referencia "Meli Envios" (display)
- **WHEN** o conteúdo contém `Meli Envios` como texto de exibição (título, caption, descrição)
- **THEN** deve ser substituído por `Logística Envios`

#### Scenario: Nome de container Docker usa "meli-envios"
- **WHEN** o `docker-compose.yml` define `container_name` com prefixo `meli-envios`
- **THEN** o container name deve usar `logistica-envios` como prefixo

#### Scenario: Runbooks referenciam container names antigos
- **WHEN** um runbook usa `docker exec -it meli-envios-kafka` ou similar
- **THEN** o comando deve referenciar `logistica-envios-kafka` (ou o nome correto atualizado)
