## Why

O repositório foi renomeado para `logistica-envios-demo-arch` no GitHub, mas internamente ainda usa o prefixo `meli` em nomes de arquivos, nomes de containers Docker, títulos de diagramas e referências textuais. A inconsistência dificulta a leitura e pode confundir o Codex ao gerar novos artefatos com o prefixo errado.

## What Changes

- Renomear 7 arquivos cujo nome contém `meli` (3 `.puml`, 3 `.svg`, 1 `.yaml`)
- Substituir todas as ocorrências de `meli-envios` e `meli_envios` no conteúdo de arquivos `.md`, `.puml`, `.yaml` e `.yml` pelo equivalente `logistica-envios`
- Substituir ocorrências isoladas de `Meli Envios` (texto display) por `Logística Envios`
- Atualizar nomes de containers Docker no `docker-compose.yml` (`meli-envios-kafka` → `logistica-envios-kafka`, etc.)
- Atualizar referências de container name em runbooks e docs que citam os nomes Docker
- Atualizar o campo `job_name` em `monitoring/grafana/provisioning/dashboards/dashboards.yaml`

## Capabilities

### New Capabilities

- `rename-meli-to-logistica`: Renomeação global de prefixo `meli` → `logistica` em nomes de arquivos e conteúdo do repositório

### Modified Capabilities

<!-- Nenhuma capability existente muda requisito — é apenas refatoração de nomenclatura -->

## Impact

- **Arquivos renomeados**: `docs/c4/meli-envios-*.puml`, `docs/c4/meli-envios-*.svg`, `docs/contracts/meli-envios-apis.openapi.yaml`
- **Conteúdo atualizado**: `docker-compose.yml`, todos os `.md` em `docs/`, arquivos `.yaml`/`.yml` em `monitoring/`
- **Runbooks afetados**: referências a `logistica-envios-kafka`, `logistica-envios-postgres`, `logistica-envios-redis` nos comandos `docker exec`
- **Sem breaking change funcional**: apenas renomeação de strings — nenhum contrato de API ou schema Kafka muda
- **SVGs regenerados**: após renomear os `.puml`, os SVGs correspondentes devem ser re-gerados
