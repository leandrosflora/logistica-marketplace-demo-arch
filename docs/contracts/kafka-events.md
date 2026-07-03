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
| `checkout.shipping.quote.requested` | `CheckoutService` | `ShippingPromiseService`, `AuditService` | Implementado |
| `shipping.promise.calculated` | `ShippingPromiseService` | `CheckoutService`, `AuditService` | Implementado |

### Checkout e pedido

| Tópico | Producer | Consumer | Status prático |
|---|---|---|---|
| `checkout.confirmed` | `CheckoutService` | `OrderService`, `AuditService` | Implementado |
| `order.created` | `OrderService` | `ShipmentService`, `NotificationService`, `AuditService` | Implementado |
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
| `payment.commands` | `OrderService` | `PaymentService` | Implementado |
| `payment.approved` | `PaymentService` | `OrderService`, `AuditService` | Implementado |
| `payment.rejected` | `PaymentService` | `NotificationService`, `OrderService`, `AuditService` | Implementado |
| `payment.captured` | `PaymentService` | `OrderService`, `AuditService` | Implementado |
| `payment.capture.failed` | `PaymentService` | `OrderService`, `AuditService` | Implementado |

`PaymentService` não integra com um gateway/PSP real; usa um adaptador mock determinístico (ver [docs/services/payment-service.md](../services/payment-service.md)).

### Shipment e tracking

| Tópico | Producer | Consumer | Status prático |
|---|---|---|---|
| `shipment.commands` | `OrderService` | `ShipmentService` | Implementado |
| `order.created` | `OrderService` | `ShipmentService` | Implementado |
| `shipment.created` | `ShipmentService` | `TrackingService`, `NotificationService`, `OrderService`, `AuditService` | Implementado |
| `shipment.status.updated` | `TrackingService` | `OrderService`, `NotificationService`, `AuditService` | Implementado |
| `carrier-shipment.commands` | `ShipmentService` | Nenhum consumer localizado | Produzido sem consumidor; integração com carrier pendente/simulada |

## Tópicos configurados em consumer, mas sem producer implementado

Os tópicos abaixo aparecem em configurações de consumer, principalmente no `NotificationService`, mas não há producer implementado nos microservices atuais:

| Tópico | Consumer configurado | Situação |
|---|---|---|
| `order.confirmed` | `NotificationService` | Producer canônico não localizado. O `OrderService` escreve confirmação em `order.events`, não em `order.confirmed`. |
| `order.cancelled` | `NotificationService` | Producer canônico não localizado. O `OrderService` escreve cancelamento em `order.events`. |
| `shipment.cancelled` | `NotificationService` | Producer ausente no `ShipmentService` atual. Cancelamento escreve `carrier-shipment.commands`. |
| `shipment.creation.failed` | `OrderService` | Configurado no `KafkaOptions`, mas consumer registrado no `Program.cs` não foi localizado. |

## Contrato de envelope recomendado

Para eventos canônicos e mensagens de integração, manter envelope com:

```json
{
  "eventId": "uuid",
  "eventType": "shipment.status.updated",
  "schemaVersion": "1.0",
  "occurredAt": "2026-06-14T12:00:00Z",
  "correlationId": "uuid",
  "traceId": "hex-string",
  "spanId": "hex-string",
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

### `traceId` / `spanId` (opcionais, rollout incremental)

Adicionados para permitir que o `OrderVisibilityService` (ver [order-visibility-service.md](../services/order-visibility-service.md)) linke um evento da timeline diretamente a um trace no Jaeger. São **opcionais e aditivos**: populados a partir do `Activity.Current` (OpenTelemetry) no momento em que o evento é gravado no outbox, e ausentes quando não há uma activity ativa. Nenhum consumidor deve exigir esses campos; quando ausentes, a correlação por `correlationId` continua sendo o caminho padrão.

Status de adoção por producer (2026-07-02):

| Producer | `traceId`/`spanId` no envelope |
|---|---|
| `CheckoutService` | Implementado (`checkout.shipping.quote.requested`, `checkout.confirmed`) |
| `FulfillmentCenterService` | Implementado (`fulfillment.capacity.reserved/confirmed/failed`) |
| `OrderService` | Pendente |
| `InventoryService` | Pendente |
| `PaymentService` | Pendente |
| `ShipmentService` | Pendente |
| `TrackingService` | Pendente |

Os produtores pendentes constroem o envelope em pontos diferentes do código (alguns no momento da escrita no outbox, outros só no dispatcher em background, onde não há mais uma `Activity` HTTP ativa); adicionar os campos nesses casos exige capturar `traceId`/`spanId` no momento da escrita e propagá-los até o dispatcher, o que é maior que uma mudança aditiva de uma linha. Tratar como trabalho de acompanhamento, não bloqueador — o `OrderVisibilityService` já funciona plenamente via busca por `correlation.id` no Jaeger quando `traceId` está ausente.

## Matriz resumida

| Tópico | Producer | Consumer principal | Classificação |
|---|---|---|---|
| `checkout.shipping.quote.requested` | `CheckoutService` | `ShippingPromiseService`, `AuditService` | Evento implementado |
| `shipping.promise.calculated` | `ShippingPromiseService` | `CheckoutService`, `AuditService` | Evento implementado |
| `checkout.confirmed` | `CheckoutService` | `OrderService`, `AuditService` | Evento implementado |
| `order.created` | `OrderService` | `ShipmentService`, `NotificationService`, `AuditService` | Evento implementado |
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
| `payment.commands` | `OrderService` | `PaymentService` | Comando interno implementado |
| `payment.approved` | `PaymentService` | `OrderService`, `AuditService` | Evento implementado |
| `payment.rejected` | `PaymentService` | `NotificationService`, `OrderService`, `AuditService` | Evento implementado |
| `payment.captured` | `PaymentService` | `OrderService`, `AuditService` | Evento implementado |
| `payment.capture.failed` | `PaymentService` | `OrderService`, `AuditService` | Evento implementado |
| `shipment.commands` | `OrderService` | `ShipmentService` | Comando interno implementado |
| `shipment.created` | `ShipmentService` | `TrackingService`, `NotificationService`, `OrderService`, `AuditService` | Evento implementado |
| `shipment.status.updated` | `TrackingService` | `OrderService`, `NotificationService`, `AuditService` | Evento implementado |
| `carrier-shipment.commands` | `ShipmentService` | Não localizado | Pendente |
| `order.events` | `OrderService` | Interno/controlado | Interno |

## Decisão prática

A documentação deve tratar o E2E atual como **parcial**:

- completo para checkout → promise → order → inventory/fulfillment → payment → shipment → tracking/notification;
- auditoria coberta pelo `AuditService` para os dez tópicos canônicos com producer real (ver [audit-service.md](../services/audit-service.md));
- incompleto para alguns eventos de notificação configurados sem producer canônico.
