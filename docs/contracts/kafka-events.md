# Eventos Kafka

## Envelope padrão

Todos os eventos canônicos Kafka devem usar o envelope abaixo:

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

## Regras de contrato

1. `eventType` deve ser igual ao nome do tópico canônico.
2. `eventId` deve ser globalmente único.
3. `correlationId` deve ser propagado entre serviços.
4. `payload` deve conter todos os campos necessários para os consumers declarados.
5. Eventos canônicos representam fatos de negócio já ocorridos.
6. Comandos internos de saga não devem ser tratados como eventos canônicos.
7. Os nomes dos campos do payload devem ser serializados em `camelCase`.

## Tópicos canônicos

### `checkout.shipping.quote.requested`

Publicado por: `checkout-service`

Consumido por: `shipping-promise-service`, `audit-service`, `analytics`

Payload canônico:

```json
{
  "checkoutId": "uuid",
  "buyerId": "uuid",
  "sellerId": "uuid",
  "destination": {
    "zipCode": "05700-000",
    "city": "São Paulo",
    "state": "SP",
    "country": "BR"
  },
  "items": [
    {
      "skuId": "uuid",
      "sellerId": "uuid",
      "quantity": 1,
      "unitPrice": 129.9
    }
  ]
}
```

`checkoutId` deve ser propagado no fluxo de promise para permitir que o `CheckoutService` associe a resposta assíncrona ao checkout original.

### `shipping.promise.calculated`

Publicado por: `shipping-promise-service`

Consumido por: `checkout-service`, `audit-service`, `analytics`

Payload canônico:

```json
{
  "checkoutId": "uuid",
  "buyerId": "uuid",
  "sellerId": "uuid",
  "promiseId": "promise_123",
  "mode": "same_day",
  "carrier": "carrier_1",
  "estimatedDeliveryDate": "2026-06-15",
  "cost": 14.9,
  "currency": "BRL",
  "source": "calculated"
}
```

`checkoutId` é obrigatório para o consumer do `CheckoutService`.

### `order.created`

Publicado por: `order-service`

Consumido por: `shipment-service`, `notification-service`, `audit-service`

Payload canônico:

```json
{
  "orderId": "uuid",
  "checkoutId": "uuid",
  "buyerId": "uuid",
  "sellerId": "uuid",
  "shippingPromiseId": "promise_123",
  "routeId": "route_123",
  "carrierCode": "carrier_1",
  "serviceLevelCode": "same_day",
  "originNodeId": "uuid",
  "promisedDeliveryDate": "2026-06-15",
  "destination": {
    "street": "Av. Paulista",
    "number": "1000",
    "city": "São Paulo",
    "state": "SP",
    "zipCode": "01310-100",
    "country": "BR"
  },
  "packages": [
    {
      "packageId": "pkg_123",
      "weightKg": 1.2,
      "heightCm": 10,
      "widthCm": 20,
      "lengthCm": 30,
      "items": [
        {
          "skuId": "uuid",
          "quantity": 1
        }
      ]
    }
  ],
  "totalAmount": 129.9,
  "currency": "BRL",
  "createdAt": "2026-06-14T12:00:00Z"
}
```

Esse contrato está enriquecido para permitir que o `ShipmentService` crie a entrega no E2E local sem lookup adicional obrigatório.

### `shipment.created`

Publicado por: `shipment-service`

Consumido por: `tracking-service`, `notification-service`, `audit-service`

Payload canônico:

```json
{
  "shipmentId": "uuid",
  "orderId": "uuid",
  "buyerId": "uuid",
  "carrierCode": "carrier_1",
  "serviceLevelCode": "same_day",
  "externalShipmentId": "ext_123",
  "trackingCode": "BR123456789",
  "labelObjectKey": "labels/shp_123.pdf",
  "estimatedDeliveryDate": "2026-06-15",
  "createdAt": "2026-06-14T12:00:00Z"
}
```

`orderId` e `buyerId` devem ser propagados para permitir que `TrackingService` e `NotificationService` publiquem/consumam eventos posteriores sem lookup adicional obrigatório.

### `shipment.status.updated`

Publicado por: `tracking-service`

Consumido por: `notification-service`, `audit-service`, `order-service`

Payload canônico:

```json
{
  "shipmentId": "uuid",
  "orderId": "uuid",
  "buyerId": "uuid",
  "trackingCode": "BR123456789",
  "carrierCode": "carrier_1",
  "previousStatus": "in_transit",
  "currentStatus": "delivered",
  "statusDate": "2026-06-16T18:00:00Z",
  "estimatedDeliveryDate": "2026-06-16",
  "exceptionCode": null
}
```

`orderId` é obrigatório para atualização do pedido no `OrderService`; `buyerId` é obrigatório para planejamento de notificação no `NotificationService`.

## Matriz final dos contratos canônicos

| Tópico | Producer | Consumers | Payload obrigatório | Status |
|---|---|---|---|---|
| `checkout.shipping.quote.requested` | `checkout-service` | `shipping-promise-service`, `audit-service`, `analytics` | `checkoutId`, `buyerId`, `sellerId`, `destination`, `items[]` | Alinhado |
| `shipping.promise.calculated` | `shipping-promise-service` | `checkout-service`, `audit-service`, `analytics` | `checkoutId`, `buyerId`, `sellerId`, `promiseId`, `mode`, `carrier`, `estimatedDeliveryDate`, `cost`, `currency`, `source` | Alinhado |
| `order.created` | `order-service` | `shipment-service`, `notification-service`, `audit-service` | `orderId`, `checkoutId`, `buyerId`, `sellerId`, `shippingPromiseId`, `routeId`, `carrierCode`, `serviceLevelCode`, `originNodeId`, `promisedDeliveryDate`, `destination`, `packages[]`, `totalAmount`, `currency`, `createdAt` | Alinhado |
| `shipment.created` | `shipment-service` | `tracking-service`, `notification-service`, `audit-service` | `shipmentId`, `orderId`, `buyerId`, `carrierCode`, `serviceLevelCode`, `externalShipmentId`, `trackingCode`, `labelObjectKey`, `estimatedDeliveryDate`, `createdAt` | Alinhado |
| `shipment.status.updated` | `tracking-service` | `notification-service`, `audit-service`, `order-service` | `shipmentId`, `orderId`, `buyerId`, `trackingCode`, `carrierCode`, `previousStatus`, `currentStatus`, `statusDate`, `estimatedDeliveryDate`, `exceptionCode` | Alinhado |

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
