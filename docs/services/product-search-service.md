# Product Search Service

## Responsabilidade real no código

Busca produtos ativos para o marketplace a partir de texto livre, paginação e filtros simples de contexto logístico.

O serviço entrega cards de produto para o BFF/frontend e funciona como camada de leitura. No código atual, ele **não consulta Product Catalog, Inventory, Pricing ou Shipping em tempo real** durante a busca.

## Implementação atual

| Aspecto | Situação no código |
|---|---|
| Stack | .NET 8, ASP.NET Core Minimal APIs |
| Persistência | Postgres via Dapper/Npgsql |
| Repositório registrado | `PostgresProductSearchRepository` |
| Connection string | `Default` |
| Tabela consultada | `products` |
| Busca textual | `to_tsvector('portuguese', title || ' ' || coalesce(category, ''))` + fallback `ILIKE` |
| Filtro base | `lower(status) = 'active'` |
| OpenSearch | Existe como estrutura/evolução, mas **não é o runtime registrado no Program.cs atual** |

## APIs publicadas

| Método | Endpoint | Descrição |
|---|---|---|
| `GET` | `/v1/products/search` | Busca produtos por texto livre, página, tamanho de página, CEP e região |
| `GET` | `/health` | Health check |
| `GET` | `/health/live` | Liveness |
| `GET` | `/health/ready` | Readiness |

Não há endpoint implementado para `GET /v1/products/{skuId}` neste serviço.

## Parâmetros de busca

| Parâmetro | Tipo | Obrigatório | Observação |
|---|---|---|---|
| `query` | string | Sim | Texto pesquisado pelo usuário |
| `page` | int | Não | Página da paginação |
| `pageSize` | int | Não | Tamanho da página |
| `zipCode` | string | Não | Contexto logístico futuro |
| `region` | string | Não | Contexto/filtro logístico futuro |

## Dados retornados

A resposta é montada a partir das colunas:

- `id`;
- `sku_id`;
- `seller_id`;
- `title`;
- `price`.

Campos como imagem, estoque, avaliação, frete grátis, fulfillment e promise são retornados com valores vazios/nulos/default no mapper atual.

## Eventos Kafka publicados

Nenhum.

## Eventos Kafka consumidos

Nenhum.

## Dependências síncronas

Nenhuma dependência síncrona com outros microservices no código atual.

## Persistência e infraestrutura

| Recurso | Uso |
|---|---|
| Postgres | Read model de produtos ativos para busca |
| Redis | Não registrado no bootstrap atual |
| Kafka | Não utilizado diretamente |
| OpenSearch | Planejado/evolutivo; não registrado como implementação ativa |

A matriz consolidada de dados fica em [data-stores.md](../contracts/data-stores.md).

## SLOs sugeridos

| Métrica | Objetivo |
|---|---|
| Disponibilidade | ≥ 99.5% |
| Error rate 5xx | < 1% |
| Latência P99 `GET /v1/products/search` | < 300 ms |
| Latência P50 `GET /v1/products/search` | < 80 ms |

## Regras práticas

1. Busca deve consultar apenas produtos ativos.
2. Resultado vazio é aceitável; latência alta não.
3. O serviço não é fonte canônica de catálogo, estoque ou preço.
4. OpenSearch só deve ser descrito como evolução enquanto o `Program.cs` registrar `PostgresProductSearchRepository`.

## Decisões arquiteturais relacionadas

- [ADR-0003 — Arquitetura Hexagonal](../adr/0003-hexagonal-clean-architecture.md)
