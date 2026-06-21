# Product Search Service

## Responsabilidade

Busca e rankeia produtos ofertados no marketplace a partir de texto livre e filtros (categoria, preço, seller). Alimenta o BFF e o frontend com resultados de busca e listagem de produtos. É o ponto de entrada da jornada de descoberta de produtos.

## Dados dominados

- **Índice de produtos ofertados**: snapshots indexados de produtos com disponibilidade, preço e seller.

## APIs publicadas

| Método | Endpoint | Descrição |
|---|---|---|
| `GET` | `/v1/products/search` | Busca produtos por texto livre e/ou filtros |
| `GET` | `/v1/products/{skuId}` | Retorna detalhes de um produto específico para exibição |

## Eventos Kafka publicados

Nenhum.

## Eventos Kafka consumidos

Nenhum diretamente. O índice de produtos pode ser alimentado por eventos de domínio de catálogo (fora do escopo deste case).

## Dependências síncronas

Nenhuma direta (índice local).

## SLOs

| Métrica | Objetivo |
|---|---|
| Disponibilidade | TBD |
| Latência P99 `GET /products/search` | TBD (crítico para UX de busca) |

## Regras de negócio principais

1. Busca DEVE retornar resultados relevantes dentro do prazo de SLO; resultado vazio é preferível a latência alta.
2. Produto sem estoque DEVE ser filtrado ou marcado como indisponível nos resultados.
3. Resultados DEVEM incluir `skuId`, `sellerId`, `title`, `price`, `thumbnailUrl`, `availableQuantity`.

## Decisões arquiteturais relacionadas

- [ADR-0003 — Arquitetura Hexagonal](../adr/0003-hexagonal-clean-architecture.md)
