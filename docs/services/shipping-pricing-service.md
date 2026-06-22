# Shipping Pricing Service

## Responsabilidade

Calcula o custo de frete, custo logístico interno, subsídios aplicáveis e promoções de frete grátis para uma rota, transportadora e pacote específicos. Retorna o preço final cobrado ao buyer e o custo interno para o seller/marketplace.

## Dados dominados

- **FreightPrice**: preço de frete calculado para rota/carrier/pacote, com custo bruto, subsídio e custo final ao buyer.
- **SubsidyRule**: regras de subsídio de frete por seller, categoria ou promoção.

## APIs publicadas

| Método | Endpoint | Descrição |
|---|---|---|
| `POST` | `/v1/pricing/freight` | Calcula custo de frete para rota/carrier/pacote |

## Eventos Kafka publicados

Nenhum.

## Eventos Kafka consumidos

Nenhum.

## Dependências síncronas

Nenhuma direta (regras de negócio proprietárias).

## Persistência e infraestrutura

| Recurso | Uso |
|---|---|
| Postgres schema `shipping_pricing` | Persistência de `FreightPrice`, `RateCard`, `SubsidyRule` e promoções |
| Redis | Cache de regras de subsídio, rate cards e cotações recentes |
| Kafka | Não utilizado diretamente no escopo atual |

A matriz consolidada de dados fica em [data-stores.md](../contracts/data-stores.md).

## SLOs

| Métrica | Objetivo | Error Budget (30d) |
|---|---|---|
| Disponibilidade | ≥ 99.9% | 43 min/mês |
| Error rate (5xx) | < 0.1% das requisições | — |
| Latência P99 `POST /v1/shipping-prices/quotes/batch` | < 150 ms | — |

## Regras de negócio principais

1. Cálculo DEVE considerar: dimensões do pacote, rota, transportadora, promoções ativas e regras de subsídio do seller.
2. Subsídio NUNCA pode resultar em custo negativo ao buyer (mínimo: R$ 0,00).
3. Resultado DEVE separar: `grossCost` (custo logístico real), `subsidyAmount` (subsídio aplicado), `buyerCost` (valor cobrado ao buyer).
4. Cache de regras de subsídio DEVE ser invalidado quando promoções são atualizadas.

## Decisões arquiteturais relacionadas

- [ADR-0003 — Arquitetura Hexagonal](../adr/0003-hexagonal-clean-architecture.md)
