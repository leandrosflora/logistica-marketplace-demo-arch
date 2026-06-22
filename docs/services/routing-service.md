# Routing Service

## Responsabilidade

Calcula rotas logísticas entre origens (FCs) e destinos (CEP do buyer), determinando a malha, hubs intermediários, janelas de trânsito e SLA de entrega para cada modalidade disponível.

## Dados dominados

- **Route**: rota calculada entre origem e destino, com `routeId`, hubs, SLA e corredor logístico.
- **LogisticNetwork**: malha de rotas, corredores e hubs disponíveis.

## APIs publicadas

| Método | Endpoint | Descrição |
|---|---|---|
| `POST` | `/v1/routes/calculate` | Calcula rotas para origem/destino/modalidade |
| `GET` | `/v1/routes/{routeId}` | Retorna detalhes de uma rota calculada |

## Eventos Kafka publicados

Nenhum.

## Eventos Kafka consumidos

Nenhum.

## Dependências síncronas

Nenhuma (dados proprietários de malha logística).

## Persistência e infraestrutura

| Recurso | Uso |
|---|---|
| Postgres schema `routing` | Persistência de `LogisticNetwork`, hubs, lanes e rotas calculadas |
| Redis | Cache de rotas e SLA por origem/destino/modalidade |
| Kafka | Não utilizado diretamente no escopo atual |

A matriz consolidada de dados fica em [data-stores.md](../contracts/data-stores.md).

## SLOs

| Métrica | Objetivo | Error Budget (30d) |
|---|---|---|
| Disponibilidade | ≥ 99.9% | 43 min/mês |
| Error rate (5xx) | < 0.1% das requisições | — |
| Latência P99 `POST /v1/routes/search` | < 200 ms | — |
| Cache hit rate de rotas (Redis) | ≥ 90% | — |

## Regras de negócio principais

1. DEVE retornar ao menos uma rota para qualquer par origem/destino válido dentro do território de operação.
2. SLA de cada rota DEVE considerar cutoff do FC de origem.
3. `routeId` DEVE ser estável para o mesmo par origem/destino/modalidade dentro de um período (não mudar entre cotação e criação de pedido).

## Decisões arquiteturais relacionadas

- [ADR-0003 — Arquitetura Hexagonal](../adr/0003-hexagonal-clean-architecture.md)
