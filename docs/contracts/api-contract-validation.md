# Validação de contratos HTTP - Logística Envios

Data da revalidação: 2026-06-14

## Objetivo

Revalidar os contratos HTTP dos repositórios envolvidos no case Logística Envios após a correção das 8 pendências apontadas na validação anterior.

Arquivo OpenAPI consolidado de referência:

- [`logistica-envios-apis.openapi.yaml`](logistica-envios-apis.openapi.yaml)

## Método de validação

A validação priorizou o código atual dos endpoints e clients HTTP dos repositórios:

- `Api/*Endpoints.cs`
- `Clients/*Client.cs`
- `Contracts/*.cs`
- `Program.cs`, quando necessário para confirmar o mapeamento de endpoints

## Resultado executivo

As 8 pendências críticas apontadas na validação anterior foram corrigidas.

| Item | Validação | Status |
|---|---|---:|
| 1 | `ShippingPromiseService -> FulfillmentCenterService` mapeia o response real do Fulfillment. | OK |
| 2 | `ShippingPromiseService -> RoutingService` lê `SearchRoutesResponse.routes[]` e mapeia para `RouteOption`. | OK |
| 3 | `ShippingPromiseService -> CarrierService` envia `checkId` em cada item de `checks`. | OK |
| 4 | `ShippingPromiseService -> ShippingPricingService` envia `buyerId`, `sellerId`, `destinationPostalCode`, `cartTotal`, `currency` e `candidates[]`. | OK |
| 5 | `MarketplaceWeb.Bff -> TrackingService` chama `GET /tracking/shipments/{shipmentId}`. | OK |
| 6 | `MarketplaceWeb.Bff -> OrderService` não chama mais `GET /orders`. | OK |
| 7 | `MarketplaceWeb.Bff -> OrderService` envia body de cancelamento e trata `202 Accepted` sem body. | OK |
| 8 | `MarketplaceWeb.Bff -> ShipmentService` trata label como JSON com `url` e `expiresInSeconds`. | OK |

## Status por componente

| Componente | Status | Resultado |
|---|---:|---|
| MarketplaceWeb | N/A | Frontend web; não expõe API downstream. |
| MarketplaceWeb.Bff | OK | Endpoints e clients downstream revalidados. |
| ProductSearchService | OK | `GET /v1/products/search` compatível com BFF. |
| ProductCatalogService | OK | `GET /products/{skuId}` e `POST /products/physical-info/batch` compatíveis. |
| CheckoutService | OK | `POST /checkouts`, `GET /checkouts/{checkoutId}` e `POST /checkouts/{checkoutId}/confirm` compatíveis com BFF. |
| ShippingPromiseService | OK | Endpoint público e clients downstream revalidados. |
| InventoryService | OK | Endpoint e response compatíveis com `ShippingPromiseService`. |
| FulfillmentCenterService | OK | Rota, request e response agora compatíveis via adapter do `ShippingPromiseService`. |
| RoutingService | OK | Rota e response agora compatíveis via adapter do `ShippingPromiseService`. |
| CarrierService | OK | Request agora inclui `checkId` obrigatório. |
| ShippingPricingService | OK | Request e response agora compatíveis via adapter do `ShippingPromiseService`. |
| OrderService | OK | Consulta por ID e cancelamento compatíveis com BFF. |
| ShipmentService | OK | Label JSON compatível com BFF. |
| TrackingService | OK | Rota de consulta por shipment compatível com BFF. |
| NotificationService | OK | Endpoints HTTP batem com a documentação atual. |

## Revalidação das pendências anteriores

### 1. ShippingPromiseService -> FulfillmentCenterService

**Status:** OK.

O client continua chamando:

```http
POST /fulfillment-centers/candidates/search
```

E agora desserializa o response real do `FulfillmentCenterService` em um DTO downstream específico:

```csharp
FulfillmentCenterCandidateResponse(
  Guid FulfillmentCenterId,
  string Region,
  DateTimeOffset CutoffAt,
  int AvailableCapacityUnits,
  int Score)
```

Depois mapeia para o modelo interno:

```csharp
FulfillmentCandidate(
  FulfillmentCenterId,
  Region,
  TimeOnly.FromTimeSpan(CutoffAt.TimeOfDay),
  AvailableCapacityUnits > 0,
  Score)
```

Resultado: a incompatibilidade entre `cutoffAt`/`availableCapacityUnits`/`score` e `cutoffTime`/`hasCapacity`/`capacityScore` foi resolvida.

---

### 2. ShippingPromiseService -> RoutingService

**Status:** OK.

O client continua chamando:

```http
POST /routes/search
```

E agora desserializa o objeto correto:

```csharp
SearchRoutesResponse(IReadOnlyList<RouteResponse>? Routes)
```

Depois mapeia cada rota para `RouteOption`, usando:

- `route.routeId`
- `route.originNodeId`
- `route.destinationNodeId`
- `route.totalElapsedMinutes`
- `route.legs[0].carrierCode`
- `route.legs[0].serviceLevelCode` ou `route.legs[0].mode`

Resultado: a incompatibilidade anterior, em que o client tentava ler diretamente `List<RouteOption>`, foi resolvida.

---

### 3. ShippingPromiseService -> CarrierService

**Status:** OK.

O client continua chamando:

```http
POST /carrier-availability/search
```

E agora envia `checkId` em cada item de `checks`:

```csharp
checkId = $"{route.RouteId}:{route.CarrierCode}:{route.ServiceLevelCode}"
```

Resultado: o request agora atende ao contrato obrigatório do `CarrierService`.

---

### 4. ShippingPromiseService -> ShippingPricingService

**Status:** OK.

O client continua chamando:

```http
POST /shipping-prices/quotes/batch
```

E agora envia o payload esperado pelo `ShippingPricingService`:

```json
{
  "buyerId": "guid",
  "sellerId": "guid",
  "destinationPostalCode": "01310-100",
  "cartTotal": 199.90,
  "currency": "BRL",
  "requestedAtUtc": "2026-06-14T00:00:00Z",
  "candidates": []
}
```

Também passou a ler `customerPrice` como custo ao cliente:

```csharp
new ShippingPrice(price.CustomerPrice, price.Discount)
```

Resultado: a divergência `quotes[]` versus `candidates[]` e `Cost` versus `customerPrice` foi resolvida.

---

### 5. MarketplaceWeb.Bff -> TrackingService

**Status:** OK.

O BFF agora chama:

```http
GET /tracking/shipments/{shipmentId}
```

Essa é a rota real exposta pelo `TrackingService`.

**Observação menor:** o DTO do BFF ainda possui `Events`, mas o endpoint principal `GET /tracking/shipments/{shipmentId}` não retorna histórico de eventos. Isso não quebra a rota principal, mas se a UI precisar do histórico, o BFF deve chamar também:

```http
GET /tracking/shipments/{shipmentId}/events
```

ou tornar `Events` opcional e tratar lista vazia.

---

### 6. MarketplaceWeb.Bff -> OrderService - listagem

**Status:** OK.

O BFF removeu a chamada:

```http
GET /orders
```

O endpoint público do BFF agora expõe apenas consulta por pedido:

```http
GET /api/web/v1/orders/{orderId}
```

E o client chama corretamente:

```http
GET /orders/{orderId}
```

Resultado: a divergência com a listagem inexistente no `OrderService` foi resolvida.

---

### 7. MarketplaceWeb.Bff -> OrderService - cancelamento

**Status:** OK.

O BFF agora recebe `CancelOrderRequest`, repassa o body ao `OrderService` e trata a resposta como `202 Accepted` sem body.

Fluxo validado:

```http
POST /api/web/v1/orders/{orderId}/cancel
Idempotency-Key: {key}
Content-Type: application/json

{
  "reason": "Solicitação do comprador"
}
```

Downstream:

```http
POST /orders/{orderId}/cancel
Idempotency-Key: {key}
Content-Type: application/json

{
  "reason": "Solicitação do comprador"
}
```

Resultado: a divergência de body e response foi resolvida.

---

### 8. MarketplaceWeb.Bff -> ShipmentService - label

**Status:** OK.

O `ShipmentService` retorna:

```json
{
  "url": "https://shipment.local/labels/...pdf",
  "expiresInSeconds": 300
}
```

O BFF agora desserializa esse JSON como:

```csharp
ShipmentLabelDto(string Url, int ExpiresInSeconds)
```

E retorna `200 OK` com o mesmo payload para o frontend.

Resultado: a divergência entre PDF binário esperado e JSON real foi resolvida.

## Pendências remanescentes

Não encontrei pendência crítica de contrato HTTP entre BFF/microservices após as 8 correções.

Há apenas duas recomendações de limpeza:

1. Atualizar o OpenAPI consolidado para refletir que `GET /api/web/v1/shipments/{shipmentId}/label` retorna JSON, não `application/pdf`.
2. Decidir se o BFF deve buscar histórico de tracking em `GET /tracking/shipments/{shipmentId}/events` ou se `Events` deve ser tratado como lista opcional/vazia.

## Decisão de contrato

A regra continua válida:

> O contrato canônico é sempre o contrato do serviço dono da API. Clients consumidores devem se adaptar ao serviço dono, e não o contrário.
