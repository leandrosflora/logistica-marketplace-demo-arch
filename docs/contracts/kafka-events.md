# Eventos Kafka

## Fonte de verdade

Este arquivo reflete a varredura do código dos microservices em **2026-06-25**.

Foram considerados:

- `Program.cs`, para hosted services, producers, consumers e dispatchers registrados;
- `Infrastructure/Messaging/KafkaOptions.cs`, para nomes de tópicos configurados;
- handlers principais de saga quando necessário para entender tópicos escritos na outbox.

## Regra de leitura deste documento

| Status | Significado |
|---|---|
| Implementado | Há producer e/ou consumer registrado no código atual. |
| Produzido sem consumidor | O tópico é escrito por algum serviço, mas não há consumer implementado no conjunto atual. |
| Configurado sem producer | Algum consumer está configurado para ouvir o tópico, mas nenhum producer foi localizado. |
| Interno | Tópico de implementação da saga, não evento canônico público. |
| Pendente | Depende de microservice ainda não implementado. |

## Tópicos efetivamente implementados

### Promise de frete

| Tópico | Producer | Consumer | Status prático |
|---|---|---|---|
| `checkout.shipping.quote.requested` | `CheckoutService` | `ShippingPromiseService` | Implementado |
| `shipping.promise.calculated` | `ShippingPromiseService` | `CheckoutService` | Implementado |

### Checkout e pedido

| Tópico | Producer | Consumer | Status prático |
|---|---|---|---|
| `checkout.confirmed` | `CheckoutService` | `OrderService` | Implementado |
| `order.created` | `OrderService` | `ShipmentService`, `NotificationService` | Implementado |
| `order.events` | `OrderService` | Consumidores internos/controlados | Interno; usado para eventos de confirmação/cancelamento no código atual |

### Saga de estoque

| Tópico | Producer | Consumer | Status prático |
|---|---|---|---|
| `inventory.commands` | `OrderService` | `InventoryService` | Implementado |
| `inventory.reserved` | `InventoryService` | `OrderService` | Implementado |
| `inventory.reservation.confirmed` | `InventoryService` | `OrderService` (`InventoryReservedConsumer` assina os dois tópicos, `inventory.reserved` e `inventory.reservation.confirmed`) | Implementado |
| `inventory.reservation.failed` | `InventoryService` | `OrderService` | Implementado |
| `inventory.reservation.released` | `InventoryService` | Não localizado | Produzido sem consumidor |
| `inventory.reservation.expired` | `InventoryService` | Não localizado | Produzido sem consumidor (renomeado de `InventoryReservationExpired`, fora do padrão `x.y.z`, para `inventory.reservation.expired`) |

### Saga de fulfillment

| Tópico | Producer | Consumer | Status prático |
|---|---|---|---|
| `fulfillment.commands` | `OrderService` | `FulfillmentCenterService` | Implementado |
| `fulfillment.capacity.reserved` | `FulfillmentCenterService` | `OrderService` | Implementado |
| `fulfillment.capacity.confirmed` | `FulfillmentCenterService` | `OrderService` (`FulfillmentCapacityReservedConsumer` assina os dois tópicos, `fulfillment.capacity.reserved` e `fulfillment.capacity.confirmed`) | Implementado |
| `fulfillment.capacity.failed` | `FulfillmentCenterService` | `OrderService` | Implementado |
| `fulfillment.capacity.reservation.expired` | `FulfillmentCenterService` | Não localizado | Produzido sem consumidor (renomeado de `FulfillmentCapacityReservationExpired`, fora do padrão `x.y.z`, para `fulfillment.capacity.reservation.expired`) |

### Pagamento

| Tópico | Producer | Consumer | Status prático |
|---|---|---|---|
| `payment.commands` | `OrderService` | Nenhum consumer implementado no conjunto atual | Produzido sem consumidor; depende de `PaymentService` ou adapter externo ainda ausente |

> `PaymentService` não existe como repositório/microservice implementado. Portanto, `payment.commands` deve ser tratado como ponto pendente/simulável da saga, não como integração E2E completa.

### Shipment e tracking

| Tópico | Producer | Consumer | Status prático |
|---|---|---|---|
| `shipment.commands` | `OrderService` | `ShipmentService` | Implementado |
| `order.created` | `OrderService` | `ShipmentService` | Implementado |
| `shipment.created` | `ShipmentService` | `TrackingService`, `NotificationService`, `OrderService` | Implementado |
| `shipment.status.updated` | `TrackingService` | `OrderService`, `NotificationService` | Implementado |
| `carrier-shipment.commands` | `ShipmentService` | Nenhum consumer localizado | Produzido sem consumidor; integração com carrier pendente/simulada |

## Tópicos configurados em consumer, mas sem producer implementado

Os tópicos abaixo aparecem em configurações de consumer, principalmente no `NotificationService`, mas não há producer implementado nos microservices atuais:

| Tópico | Consumer configurado | Situação |
|---|---|---|
| `order.confirmed` | `NotificationService` | Producer canônico não localizado. O `OrderService` escreve confirmação em `order.events`, não em `order.confirmed`. |
| `order.cancelled` | `NotificationService` | Producer canônico não localizado. O `OrderService` escreve cancelamento em `order.events`. |
| `payment.rejected` | `NotificationService` | Producer ausente porque não há `PaymentService`. |
| `shipment.cancelled` | `NotificationService` | Producer ausente no `ShipmentService` atual. Cancelamento escreve `carrier-shipment.commands`. |
| `shipment.creation.failed` | `OrderService` | Configurado no `KafkaOptions`, mas consumer registrado no `Program.cs` não foi localizado. |

## Componentes removidos da visão implementada

| Componente | Motivo |
|---|---|
| `AuditService` | Não existe repo/microservice implementado. Não deve aparecer como consumer real. |
| `PaymentService` | Não existe repo/microservice implementado. A saga ainda escreve `payment.commands`, mas sem consumidor real. |

## Contrato de envelope recomendado

Para eventos canônicos e mensagens de integração, manter envelope com:

```json
{
  "eventId": "uuid",
  "eventType": "shipment.status.updated",
  "schemaVersion": "1.0",
  "occurredAt": "2026-06-14T12:00:00Z",
  "correlationId": "uuid",
  "producer": "shipment-service",
  "payload": {}
}
```

Regras:

1. Eventos canônicos representam fatos de negócio já ocorridos.
2. Comandos internos da saga não devem ser tratados como eventos canônicos.
3. `eventType` deve bater com o tópico quando o tópico for canônico.
4. Mensagens de comando (`*.commands`) podem ter contrato próprio, mas precisam de `messageId`, chave de agregação e idempotência.
5. Tópicos sem producer ou sem consumer implementado devem continuar marcados como pendentes/parciais.

## Matriz resumida

| Tópico | Producer | Consumer principal | Classificação |
|---|---|---|---|
| `checkout.shipping.quote.requested` | `CheckoutService` | `ShippingPromiseService` | Evento implementado |
| `shipping.promise.calculated` | `ShippingPromiseService` | `CheckoutService` | Evento implementado |
| `checkout.confirmed` | `CheckoutService` | `OrderService` | Evento implementado |
| `order.created` | `OrderService` | `ShipmentService`, `NotificationService` | Evento implementado |
| `inventory.commands` | `OrderService` | `InventoryService` | Comando interno implementado |
| `inventory.reserved` | `InventoryService` | `OrderService` | Evento interno implementado |
| `inventory.reservation.confirmed` | `InventoryService` | `OrderService` | Evento interno implementado |
| `inventory.reservation.failed` | `InventoryService` | `OrderService` | Evento interno implementado |
| `inventory.reservation.released` | `InventoryService` | Não localizado | Produzido sem consumidor |
| `inventory.reservation.expired` | `InventoryService` | Não localizado | Produzido sem consumidor |
| `fulfillment.commands` | `OrderService` | `FulfillmentCenterService` | Comando interno implementado |
| `fulfillment.capacity.reserved` | `FulfillmentCenterService` | `OrderService` | Evento interno implementado |
| `fulfillment.capacity.confirmed` | `FulfillmentCenterService` | `OrderService` | Evento interno implementado |
| `fulfillment.capacity.failed` | `FulfillmentCenterService` | `OrderService` | Evento interno implementado |
| `fulfillment.capacity.reservation.expired` | `FulfillmentCenterService` | Não localizado | Produzido sem consumidor |
| `payment.commands` | `OrderService` | Não implementado | Pendente |
| `shipment.commands` | `OrderService` | `ShipmentService` | Comando interno implementado |
| `shipment.created` | `ShipmentService` | `TrackingService`, `NotificationService`, `OrderService` | Evento implementado |
| `shipment.status.updated` | `TrackingService` | `OrderService`, `NotificationService` | Evento implementado |
| `carrier-shipment.commands` | `ShipmentService` | Não localizado | Pendente |
| `order.events` | `OrderService` | Interno/controlado | Interno |

## Decisão prática

A documentação deve tratar o E2E atual como **parcial**:

- completo para checkout → promise → order → inventory/fulfillment → shipment → tracking/notification;
- incompleto na etapa de pagamento, porque o consumidor de `payment.commands` não existe;
- incompleto para auditoria, porque `AuditService` não existe;
- incompleto para alguns eventos de notificação configurados sem producer canônico.
