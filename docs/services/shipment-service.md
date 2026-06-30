# Shipment Service

## Responsabilidade real no código

Cria e consulta shipments físicos a partir de pedidos, pacotes e comandos da saga. Também gera/acessa etiqueta e solicita cancelamento junto à integração de carrier.

No código atual, o serviço consome `order.created` e `shipment.commands`, publica `shipment.created` e escreve `carrier-shipment.commands` em cancelamento.

## Dados dominados

- **Shipment**: entrega com order, carrier, service level, tracking code, label e status.
- **Package**: volume físico do shipment.
- **PackageItem**: itens contidos em cada pacote.
- **InboxMessage**: controle de idempotência de mensagens/comandos consumidos.
- **OutboxMessage**: mensagens produzidas para Kafka/integrações.

## APIs publicadas

| Método | Endpoint | Descrição |
|---|---|---|
| `GET` | `/shipments/{shipmentId}` | Retorna detalhes de um shipment |
| `GET` | `/shipments/{shipmentId}/label` | Retorna URL temporária para download da etiqueta |
| `POST` | `/shipments/{shipmentId}/cancel` | Solicita cancelamento do shipment; exige header `Idempotency-Key` |
| `GET` | `/health` | Health check |

Não há prefixo `/v1` nos endpoints de shipment do código atual.

## Eventos/comandos publicados

| Tópico | Quando | Status prático |
|---|---|---|
| `shipment.created` | Shipment criado com sucesso | Implementado |
| `carrier-shipment.commands` | Cancelamento solicitado para integração com carrier | Produzido, mas consumer não localizado no conjunto atual |

`shipment.cancelled` não aparece em `KafkaOptions` do `ShipmentService` atual e não deve ser documentado como evento publicado implementado.

## Eventos Kafka consumidos

| Tópico | Consumer group | Finalidade | Status |
|---|---|---|---|
| `order.created` | `shipment-service` | Criar shipment a partir do pedido | Implementado |
| `shipment.commands` | `shipment-service` | Criar/cancelar/atualizar shipment via saga do `OrderService` | Implementado |

`order.cancelled` não está configurado no `KafkaOptions` atual do `ShipmentService`.

## Dependências síncronas

| Serviço | Finalidade |
|---|---|
| Carrier Service | Registrar shipment, reservar/coordenar carrier e gerar etiqueta |

A integração HTTP com Carrier Service usa `HttpClient` com timeout e resiliência.

## Persistência e infraestrutura

| Recurso | Uso |
|---|---|
| Postgres `ShipmentDb` | Persistência de shipment, packages, inbox e outbox |
| FileSystemLabelStorage | Armazenamento/geração de URL temporária de etiqueta em ambiente local/demo |
| Kafka | Consumo de `order.created`/`shipment.commands`; publicação de `shipment.created` |
| Redis | Não registrado no bootstrap atual |
| OpenTelemetry | Tracing, metrics e exporter OTLP |

A matriz consolidada de dados fica em [data-stores.md](../contracts/data-stores.md).

## SLOs sugeridos

| Métrica | Objetivo |
|---|---|
| Disponibilidade | ≥ 99.9% |
| Error rate 5xx | < 0.1% |
| Latência P99 `GET /shipments/{id}` | < 150 ms |
| Tempo P95 entre consumo de `order.created` e publicação de `shipment.created` | < 60 s |

## Regras práticas

1. `shipment.created` deve ser publicado via outbox.
2. Consumers devem deduplicar mensagens via inbox.
3. `sellerId`, `orderId` e `buyerId` devem ser propagados do pedido para o shipment.
4. Cancelamento atual não publica `shipment.cancelled`; ele escreve `carrier-shipment.commands`.
5. A documentação não deve declarar `order.cancelled` como consumer do `ShipmentService` sem alteração no código.

## Decisões arquiteturais relacionadas

- [ADR-0005 — Estratégia de Idempotência](../adr/0005-idempotency-strategy.md)
- [ADR-0007 — Tópicos internos de saga](../adr/0007-order-service-internal-saga-topics.md)
