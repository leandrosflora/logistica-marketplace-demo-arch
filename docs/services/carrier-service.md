# Carrier Service

## Responsabilidade

Integra transportadoras (Correios, parceiros privados, last-mile), consulta opções disponíveis para uma rota e pacote, e filtra com base em restrições do produto e do destino.

## Dados dominados

- **CarrierOption**: opção de transportadora para uma rota, com `carrierCode`, `serviceLevel`, prazo e disponibilidade.
- **CarrierRestriction**: restrições de cobertura por CEP, tipo de produto ou peso.

## APIs publicadas

| Método | Endpoint | Descrição |
|---|---|---|
| `POST` | `/v1/carriers/options` | Retorna opções de transportadora para rota e pacote |
| `GET` | `/v1/carriers/{carrierCode}` | Retorna dados de uma transportadora |

## Eventos Kafka publicados

Nenhum.

## Eventos Kafka consumidos

Nenhum.

## Dependências síncronas

| Serviço | Finalidade |
|---|---|
| APIs externas de transportadoras | Consultar disponibilidade real-time (via circuit breaker) |

## Persistência e infraestrutura

| Recurso | Uso |
|---|---|
| Postgres schema `carrier` | Persistência de transportadoras, níveis de serviço, restrições e disponibilidade materializada |
| Redis | Cache de disponibilidade e restrições de transportadora |
| Kafka | Não utilizado diretamente no escopo atual |

A matriz consolidada de dados fica em [data-stores.md](../contracts/data-stores.md).

## SLOs

| Métrica | Objetivo | Error Budget (30d) |
|---|---|---|
| Disponibilidade | ≥ 99.5% | 3.6 h/mês |
| Error rate (5xx próprios — excluindo falhas de transportadora) | < 1% | — |
| Latência P99 `POST /v1/carrier-availability/search` (com validação real-time) | < 1 s | — |
| Taxa de respostas via cache local (sem chamada externa) | ≥ 70% | — |

## Regras de negócio principais

1. DEVE implementar circuit breaker para cada integração externa de transportadora.
2. Fallback: se integração indisponível, retornar opções baseadas em dados cacheados com TTL definido.
3. Restrições do produto (fragile, dangerous goods) DEVEM filtrar automaticamente transportadoras incompatíveis.
4. DEVE retornar resultado mesmo com algumas transportadoras indisponíveis (degradação graciosa).

## Decisões arquiteturais relacionadas

- [ADR-0003 — Arquitetura Hexagonal](../adr/0003-hexagonal-clean-architecture.md)
