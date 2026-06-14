# Eventos Kafka

## Envelope padrão

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

## Tópicos

### `checkout.shipping.quote.requested`

Publicado por: `checkout-service`

Consumido por: `audit-service`, `analytics`

Payload:

```json
{
  "checkoutId": "chk_123",
  "buyerId": "usr_123",
  "destinationZipCode": "05700-000",
  "items": [
    {
      "sku": "SKU-123",
      "sellerId": "seller-1",
      "quantity": 1
    }
  ]
}
```

### `shipping.promise.calculated`

Publicado por: `shipping-promise-service`

Consumido por: `checkout-service`, `audit-service`, `analytics`

Payload:

```json
{
  "checkoutId": "chk_123",
  "promises": [
    {
      "sku": "SKU-123",
      "available": true,
      "shippingMode": "same_day",
      "estimatedDeliveryDate": "2026-06-15",
      "price": 14.9,
      "currency": "BRL"
    }
  ]
}
```

### `order.created`

Publicado por: `order-service`

Consumido por: `shipment-service`, `notification-service`, `audit-service`

Payload:

```json
{
  "orderId": "ord_123",
  "buyerId": "usr_123",
  "items": [
    {
      "sku": "SKU-123",
      "sellerId": "seller-1",
      "quantity": 1
    }
  ],
  "shippingPromiseId": "promise_123"
}
```

### `shipment.created`

Publicado por: `shipment-service`

Consumido por: `tracking-service`, `notification-service`, `audit-service`

Payload:

```json
{
  "shipmentId": "shp_123",
  "orderId": "ord_123",
  "carrierId": "carrier_1",
  "trackingCode": "BR123456789",
  "status": "created"
}
```

### `shipment.status.updated`

Publicado por: `tracking-service`

Consumido por: `notification-service`, `audit-service`, `order-service`

Payload:

```json
{
  "shipmentId": "shp_123",
  "orderId": "ord_123",
  "previousStatus": "in_transit",
  "currentStatus": "delivered",
  "statusDate": "2026-06-16T18:00:00Z"
}
```

## Tópicos internos de saga — OrderService

Decisão arquitetural relacionada: [`ADR-0001 — Tópicos internos de saga do OrderService`](../adr/0001-order-service-internal-saga-topics.md).

Além dos tópicos canônicos de domínio, o `OrderService` utiliza tópicos internos para orquestração da saga de criação de pedido.

Esses tópicos são considerados contratos internos da saga e não devem ser consumidos diretamente por outros domínios sem decisão arquitetural explícita.

| Tópico | Tipo | Producer | Consumer principal | Finalidade |
|---|---|---|---|---|
| `inventory.commands` | Command | `order-service` | `inventory-service` | Reservar, confirmar ou liberar estoque durante a saga do pedido. |
| `fulfillment.commands` | Command | `order-service` | `fulfillment-center-service` | Validar capacidade operacional e acionar preparação logística. |
| `payment.commands` | Command | `order-service` | `payment-service` | Solicitar autorização, captura ou cancelamento de pagamento. |
| `shipment.commands` | Command | `order-service` | `shipment-service` | Solicitar criação, cancelamento ou atualização da entrega. |
| `order.events` | Internal Event | `order-service` | Consumidores internos controlados | Publicar mudanças internas do ciclo de vida do pedido. |

### Regra de uso

Tópicos `.commands` são comandos internos de orquestração e fazem parte da implementação da saga do `OrderService`.

Eles não devem ser tratados como eventos canônicos de domínio.

Eventos canônicos devem representar fatos de negócio já ocorridos, com contrato estável, versionamento e ownership claro.

Exemplos de eventos canônicos:

- `order.created`
- `order.confirmed`
- `order.cancelled`
- `payment.approved`
- `payment.rejected`
- `shipment.created`
- `shipment.cancelled`

### Critério para promoção

Um tópico interno só deve ser promovido para tópico canônico quando:

1. for consumido por múltiplos domínios independentes;
2. representar um fato de negócio estável;
3. tiver contrato versionado;
4. tiver owner definido;
5. for aprovado por nova ADR.
