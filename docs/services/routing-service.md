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

## SLOs

| Métrica | Objetivo |
|---|---|
| Disponibilidade | TBD |
| Latência P99 `POST /routes/calculate` | TBD |

## Regras de negócio principais

1. DEVE retornar ao menos uma rota para qualquer par origem/destino válido dentro do território de operação.
2. SLA de cada rota DEVE considerar cutoff do FC de origem.
3. `routeId` DEVE ser estável para o mesmo par origem/destino/modalidade dentro de um período (não mudar entre cotação e criação de pedido).

## Decisões arquiteturais relacionadas

- [ADR-0003 — Arquitetura Hexagonal](../adr/0003-hexagonal-clean-architecture.md)
