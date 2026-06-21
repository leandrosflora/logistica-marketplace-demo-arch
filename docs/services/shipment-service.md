# Shipment Service

## Responsabilidade

Cria a entrega física do pedido: gera etiqueta, define volume, atribui código de rastreio e envia o shipment para a transportadora. Gerencia o ciclo de vida do shipment desde a criação até o encerramento.

## Dados dominados

- **Shipment**: entidade de entrega com `shipmentId`, etiqueta, código de rastreio, transportadora e status.
- **ShipmentVolume**: informações de volume e pacotes do shipment.

## APIs publicadas

| Método | Endpoint | Descrição |
|---|---|---|
| `GET` | `/v1/shipments/{shipmentId}` | Retorna detalhes de um shipment |
| `POST` | `/v1/shipments/{shipmentId}/cancel` | Cancela um shipment |

## Eventos Kafka publicados

| Tópico | Quando | Schema |
|---|---|---|
| `shipment.created` | Shipment criado com sucesso | [kafka-events.md](../contracts/kafka-events.md#shipmentcreated) |
| `shipment.cancelled` | Shipment cancelado | [kafka-events.md](../contracts/kafka-events.md#novos-eventos-canônicos) |

## Eventos Kafka consumidos

| Tópico | Consumer Group | Finalidade |
|---|---|---|
| `order.created` | `shipment-service` | Criar shipment a partir do pedido |
| `order.cancelled` | `shipment-service` | Cancelar shipment se pedido for cancelado |
| `shipment.commands` | `shipment-service` | Criar/cancelar shipment via saga do OrderService |

## Dependências síncronas

| Serviço | Finalidade |
|---|---|
| APIs externas de transportadoras | Registrar shipment e gerar etiqueta |

## SLOs

| Métrica | Objetivo | Error Budget (30d) |
|---|---|---|
| Disponibilidade | ≥ 99.9% | 43 min/mês |
| Error rate (5xx) | < 0.1% das requisições | — |
| Latência P99 `GET /v1/shipments/{id}` | < 150 ms | — |
| Tempo P95 entre consumo de `order.created` e publicação de `shipment.created` | < 60 s | — |
| Taxa de shipments criados com sucesso | ≥ 99% | — |

## Regras de negócio principais

1. `shipment.created` DEVE ser publicado via Outbox Pattern para garantir entrega.
2. Consumer de `order.created` DEVE implementar Inbox Pattern (deduplicação por `eventId`).
3. `sellerId`, `orderId` e `buyerId` DEVEM ser propagados do `order.created` para o `shipment.created`.
4. Geração de etiqueta deve ter circuit breaker para APIs de transportadora.
5. Shipment DEVE incluir `externalShipmentId` (ID na transportadora) para rastreio externo.

## Decisões arquiteturais relacionadas

- [ADR-0005 — Estratégia de Idempotência](../adr/0005-idempotency-strategy.md)
- [ADR-0007 — Tópicos internos de saga](../adr/0007-order-service-internal-saga-topics.md)
