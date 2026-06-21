## Context

O repositório foi originalmente criado com prefixo `meli` (referência ao Mercado Livre) mas passou a se chamar `logistica-envios-demo-arch`. Internamente, o prefixo `meli-envios` ainda aparece em: nomes de arquivos (`.puml`, `.svg`, `.yaml`), nomes de containers Docker, títulos de diagramas PlantUML, referências textuais em docs, e nomes de `job_name` no Grafana. A substituição é puramente léxica — nenhum contrato funcional muda.

## Goals / Non-Goals

**Goals:**
- Substituir `meli-envios` → `logistica-envios` e `meli_envios` → `logistica_envios` em todo conteúdo de arquivo
- Substituir `Meli Envios` → `Logística Envios` (texto display) em títulos e descrições
- Renomear arquivos cujo nome contém `meli-envios`
- Atualizar nomes de containers Docker no `docker-compose.yml` e referências a eles nos runbooks

**Non-Goals:**
- Alterar schemas Kafka, contratos REST, ou lógica de negócio
- Renomear a pasta raiz do repositório local (já está correta no GitHub)
- Substituir ocorrências dentro de `.git/` ou `openspec/changes/`
- Alterar nomes de repositórios externos referenciados (ex: `github.com/leandrosflora/CheckoutService`)

## Decisions

**D1 — Substituição léxica direta via sed/PowerShell:**
Usar `git grep` para identificar ocorrências e substituição em batch por arquivo. Mais seguro que regex global pois permite revisar arquivo a arquivo.

**D2 — Renomear arquivos antes de atualizar conteúdo:**
Renomear primeiro os arquivos `meli-envios-*.puml/.svg/.yaml`, depois atualizar o conteúdo dos arquivos para refletir os novos nomes. Evita referências quebradas intermediárias.

**D3 — SVGs regenerados após renomear `.puml`:**
Os 3 SVGs renomeados precisam ser re-gerados com Docker após o rename dos `.puml`, pois o SVG embute o nome do arquivo fonte.

**D4 — Manter `docs/contracts/logistica-envios-apis.openapi.yaml` como nome canônico:**
O arquivo `meli-envios-apis.openapi.yaml` passa a se chamar `logistica-envios-apis.openapi.yaml` — referências a ele no README e em outros docs são atualizadas junto.

**D5 — Exclusões explícitas:**
Não substituir dentro de: `.git/`, `openspec/changes/` (histórico de planejamento), `.vs/` (metadados do Visual Studio), nomes de repositórios GitHub externos.

## Risks / Trade-offs

- **Links externos quebrados**: qualquer link externo apontando para `meli-envios-apis.openapi.yaml` pelo nome exato precisará ser atualizado manualmente.
- **SVGs desatualizados temporariamente**: entre o rename dos `.puml` e a re-geração dos SVGs, os SVGs estarão com nome errado no conteúdo interno — aceitável pois são re-gerados na mesma sessão.
- **Docker containers em execução**: se o `docker-compose up` estiver ativo durante o rename, os container names não mudarão até `docker compose down && up`. Documentar no runbook.
