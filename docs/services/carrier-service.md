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

## SLOs

| Métrica | Objetivo |
|---|---|
| Disponibilidade | TBD |
| Latência P99 `POST /carriers/options` | TBD |

## Regras de negócio principais

1. DEVE implementar circuit breaker para cada integração externa de transportadora.
2. Fallback: se integração indisponível, retornar opções baseadas em dados cacheados com TTL definido.
3. Restrições do produto (fragile, dangerous goods) DEVEM filtrar automaticamente transportadoras incompatíveis.
4. DEVE retornar resultado mesmo com algumas transportadoras indisponíveis (degradação graciosa).

## Decisões arquiteturais relacionadas

- [ADR-0003 — Arquitetura Hexagonal](../adr/0003-hexagonal-clean-architecture.md)
