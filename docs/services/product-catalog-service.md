# Product Catalog Service

## Responsabilidade

Fornece atributos logísticos dos produtos: peso, dimensões, categoria e restrições de envio (ex: produto frágil, produto perigoso, restrições por região). É a fonte de verdade para dados físicos dos produtos usados no cálculo de frete.

## Dados dominados

- **Product** (atributos logísticos): peso, altura, largura, comprimento, categoria, restrições de envio.

## APIs publicadas

| Método | Endpoint | Descrição |
|---|---|---|
| `GET` | `/v1/products/{skuId}/logistics` | Retorna atributos logísticos de um SKU |
| `GET` | `/v1/products/logistics/batch` | Retorna atributos de múltiplos SKUs (query param `skuIds`) |

## Eventos Kafka publicados

Nenhum (serviço de consulta pura — não publica eventos canônicos).

## Eventos Kafka consumidos

Nenhum.

## Dependências síncronas

Nenhuma (fonte de dados proprietária).

## SLOs

| Métrica | Objetivo |
|---|---|
| Disponibilidade | TBD |
| Latência P99 GET por SKU | TBD (crítico: chamado no caminho de cotação) |
| Cache hit rate | TBD |

## Regras de negócio principais

1. Resposta DEVE incluir `weightKg`, `heightCm`, `widthCm`, `lengthCm` e `restrictionCodes[]`.
2. Cache de atributos DEVE ser usado para SKUs frequentemente consultados (TTL configurável).
3. SKU não encontrado DEVE retornar HTTP 404 (não silenciar ausência de dados).
4. Restrições de envio (`restrictionCodes`) DEVEM ser interpretadas pelo `Carrier Service` para filtrar opções de transportadora.

## Decisões arquiteturais relacionadas

- [ADR-0003 — Arquitetura Hexagonal](../adr/0003-hexagonal-clean-architecture.md)
