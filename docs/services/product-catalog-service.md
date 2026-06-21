# Product Catalog Service

## Responsabilidade

Fornece atributos logísticos dos produtos: peso, dimensões, categoria e restrições de envio (ex: produto frágil, produto perigoso, restrições por região). É a fonte de verdade para dados físicos dos produtos usados no cálculo de frete.

## Dados dominados

- **Product** (atributos logísticos): peso, altura, largura, comprimento, categoria, restrições de envio.

## APIs publicadas

| Método | Endpoint | Descrição |
|---|---|---|
| `GET` | `/v1/products/{skuId}` | Retorna dados gerais de um SKU |
| `GET` | `/v1/products/{skuId}/physical-info` | Retorna atributos físicos/logísticos de um SKU (peso, dimensões, restrições) |
| `POST` | `/v1/products/physical-info/batch` | Retorna atributos físicos de múltiplos SKUs (usado no fluxo de cotação) |
| `GET` | `/v1/products/{skuId}/status` | Retorna status de ativação/disponibilidade de um SKU |

## Eventos Kafka publicados

Nenhum (serviço de consulta pura — não publica eventos canônicos).

## Eventos Kafka consumidos

Nenhum.

## Dependências síncronas

Nenhuma (fonte de dados proprietária).

## SLOs

| Métrica | Objetivo | Error Budget (30d) |
|---|---|---|
| Disponibilidade | ≥ 99.95% | 21 min/mês |
| Error rate (5xx) | < 0.05% das requisições | — |
| Latência P99 `GET /v1/products/{skuId}/physical-info` | < 50 ms | — |
| Latência P99 `POST /v1/products/physical-info/batch` | < 100 ms | — |
| Cache hit rate (Redis) | ≥ 95% | — |

## Regras de negócio principais

1. Resposta DEVE incluir `weightKg`, `heightCm`, `widthCm`, `lengthCm` e `restrictionCodes[]`.
2. Cache de atributos DEVE ser usado para SKUs frequentemente consultados (TTL configurável).
3. SKU não encontrado DEVE retornar HTTP 404 (não silenciar ausência de dados).
4. Restrições de envio (`restrictionCodes`) DEVEM ser interpretadas pelo `Carrier Service` para filtrar opções de transportadora.

## Decisões arquiteturais relacionadas

- [ADR-0003 — Arquitetura Hexagonal](../adr/0003-hexagonal-clean-architecture.md)
