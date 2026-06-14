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
