# Validação de contratos HTTP - Meli Envios

Data da revalidação: 2026-06-14

## Objetivo

Revalidar os contratos HTTP dos repositórios envolvidos no case Meli Envios após os ajustes feitos nos microservices e no BFF.

Arquivo OpenAPI consolidado de referência:

- [`meli-envios-apis.openapi.yaml`](meli-envios-apis.openapi.yaml)

## Método de validação

A validação priorizou o código atual dos endpoints e clients HTTP dos repositórios:

- `Api/*Endpoints.cs`
- `Clients/*Client.cs`
- `Contracts/*.cs`
- `Program.cs`, quando necessário para confirmar o mapeamento de endpoints

Quando o código não era suficiente para inferir intenção de negócio, foi usada a documentação do próprio repositório como apoio.

## Resultado executivo

As **rotas antigas** do `ShippingPromiseService` foram majoritariamente corrigidas para as rotas reais dos serviços donos das APIs:

| Integração | Status rota | Observação |
|---|---:|---|
| ShippingPromise -> ProductCatalog | OK | Usa `POST /products/physical-info/batch`. |
| ShippingPromise -> Inventory | OK | Usa `POST /inventory/availability/batch`. |
| ShippingPromise -> FulfillmentCenter | OK | Usa `POST /fulfillment-centers/candidates/search`. |
| ShippingPromise -> Routing | OK | Usa `POST /routes/search`. |
| ShippingPromise -> Carrier | OK | Usa `POST /carrier-availability/search`. |
| ShippingPromise -> ShippingPricing | OK | Usa `POST /shipping-prices/quotes/batch`. |

Entretanto, ainda existem **incompatibilidades de request/response** que podem quebrar a jornada em runtime.

## Status por componente

| Componente | Status | Resultado |
|---|---:|---|
| MarketplaceWeb | N/A | Frontend web; não expõe API downstream. |
| MarketplaceWeb.Bff | Atenção | Endpoints existem, mas há inconsistências com Order, Tracking e Shipment. |
| ProductSearchService | OK | `GET /v1/products/search` compatível com BFF. |
| ProductCatalogService | OK | `GET /products/{skuId}` e `POST /products/physical-info/batch` compatíveis. |
| CheckoutService | OK | `POST /checkouts`, `GET /checkouts/{checkoutId}` e `POST /checkouts/{checkoutId}/confirm` compatíveis com BFF. |
| ShippingPromiseService | Atenção | Endpoint público OK, mas clients downstream ainda possuem incompatibilidades de payload/response. |
| InventoryService | OK | Endpoint e response compatíveis com `ShippingPromiseService`. |
| FulfillmentCenterService | Atenção | Rota correta, response incompatível com DTO esperado pelo `ShippingPromiseService`. |
| RoutingService | Atenção | Rota/request próximos, response incompatível com DTO esperado pelo `ShippingPromiseService`. |
| CarrierService | Atenção | Rota correta, mas request do `ShippingPromiseService` não envia `checkId`, que é obrigatório. |
| ShippingPricingService | Atenção | Rota correta, mas request e response esperados pelo `ShippingPromiseService` ainda não batem. |
| OrderService | Atenção | API pública existe, mas não possui `GET /orders` usado pelo BFF; cancelamento também diverge. |
| ShipmentService | Atenção | API pública existe, mas label retorna JSON com URL; BFF espera PDF binário. |
| TrackingService | Atenção | API pública existe, mas BFF chama rota diferente da rota real. |
| NotificationService | OK | Endpoints HTTP batem com a documentação atual. |

## Validações OK

### ProductSearchService

Endpoint validado:

```http
GET /v1/products/search?query={texto}&page={page}&pageSize={pageSize}&zipCode={zipCode}&region={region}
```

Status: **OK**.

Observação: o BFF aceita `query` ou `q`, mas sempre chama o downstream usando `query`.

---

### ProductCatalogService

Endpoints validados:

```http
POST /products/
GET /products/{skuId}
POST /products/physical-info/batch
PUT /products/{skuId}/physical-info
PATCH /products/{skuId}/status
```

Status: **OK**.

---

### CheckoutService

Endpoints validados:

```http
POST /checkouts
GET /checkouts/{checkoutId}
POST /checkouts/{checkoutId}/confirm
```

Status: **OK**.

Observação: BFF propaga `Idempotency-Key` para criação e confirmação.

---

### InventoryService

Endpoint usado pelo `ShippingPromiseService`:

```http
POST /inventory/availability/batch
```

Status: **OK**.

Request enviado pelo client:

```json
{
  "sellerId": "guid",
  "skuIds": ["guid"]
}
```

Contrato esperado pelo `InventoryService`:

```json
{
  "sellerId": "guid",
  "skuIds": ["guid"]
}
```

Response do serviço contém `skuId`, `fulfillmentCenterId` e `availableQuantity`, que são os campos necessários ao `ShippingPromiseService`.

---

## Divergências atuais

### 1. ShippingPromiseService -> FulfillmentCenterService

**Rota:** OK.

```http
POST /fulfillment-centers/candidates/search
```

**Request:** compatível.

O client envia:

```json
{
  "sellerId": "guid",
  "destinationPostalCode": "01310-100",
  "mode": "Fulfillment",
  "package": {
    "weightKg": 1.2,
    "cubicWeightKg": 1.0,
    "isFragile": false,
    "isRestricted": false
  },
  "requestedAtUtc": "2026-06-14T00:00:00Z"
}
```

O serviço espera esse formato.

**Response:** incompatível.

`FulfillmentCenterService` retorna:

```json
{
  "fulfillmentCenterId": "guid",
  "code": "FC-SP01",
  "name": "Fulfillment Center São Paulo 01",
  "region": "SP",
  "mode": "Fulfillment",
  "processingDate": "2026-06-10",
  "cutoffAt": "2026-06-10T18:00:00-03:00",
  "availableCapacityUnits": 120,
  "utilizationPercentage": 37.5,
  "score": 137
}
```

`ShippingPromiseService` tenta desserializar para:

```csharp
FulfillmentCandidate(
  Guid FulfillmentCenterId,
  string Region,
  TimeOnly CutoffTime,
  bool HasCapacity,
  int CapacityScore)
```

**Impacto provável:** `HasCapacity` tende a ficar `false` por ausência do campo no JSON, então o `ShippingPromiseService` pode descartar todos os fulfillment centers.

**Correção recomendada:** criar DTO downstream específico no `ShippingPromiseService` e mapear:

| FulfillmentCenterService | ShippingPromiseService |
|---|---|
| `fulfillmentCenterId` | `FulfillmentCenterId` |
| `region` | `Region` |
| `cutoffAt.TimeOfDay` | `CutoffTime` |
| `availableCapacityUnits > 0` | `HasCapacity` |
| `score` | `CapacityScore` |

---

### 2. ShippingPromiseService -> RoutingService

**Rota:** OK.

```http
POST /routes/search
```

**Request:** compatível em termos gerais.

O client envia `originNodeId`, `destinationPostalCode`, `package`, `requestedAtUtc` e `maxOptions`.

**Response:** incompatível.

`RoutingService` retorna um objeto:

```json
{
  "networkVersion": 2,
  "source": "Calculated",
  "routes": [
    {
      "routeId": "route_x",
      "originNodeId": "guid",
      "destinationNodeId": "guid",
      "estimatedDepartureAt": "date-time",
      "estimatedArrivalAt": "date-time",
      "totalElapsedMinutes": 390,
      "legs": []
    }
  ]
}
```

`ShippingPromiseService` tenta desserializar diretamente para:

```csharp
List<RouteOption>
```

com campos:

```csharp
RouteId,
OriginNodeId,
DestinationNodeId,
CarrierCode,
ServiceLevelCode,
TransitDays,
Available,
Priority
```

**Impacto provável:** desserialização incorreta ou lista vazia; o cálculo de promessa não consegue gerar candidatos.

**Correção recomendada:** desserializar `SearchRoutesResponse`, iterar `Routes` e mapear cada rota/leg para `RouteOption`. Exemplo de regra:

- `RouteId` <- `route.routeId`
- `OriginNodeId` <- `route.originNodeId`
- `DestinationNodeId` <- `route.destinationNodeId`
- `CarrierCode` <- `route.legs[0].carrierCode`
- `ServiceLevelCode` <- definir contrato no Routing ou inferir do carrier/mode
- `TransitDays` <- `ceil(totalElapsedMinutes / 1440)` ou campo explícito no Routing
- `Available` <- `true` quando rota existir
- `Priority` <- índice da rota ou score futuro

---

### 3. ShippingPromiseService -> CarrierService

**Rota:** OK.

```http
POST /carrier-availability/search
```

**Request:** incompatível.

`CarrierService` exige `checkId` em cada item de `checks`.

Contrato real:

```json
{
  "checks": [
    {
      "checkId": "check-001",
      "carrierCode": "MELI-LOGISTICS",
      "serviceLevelCode": "EXPRESS",
      "originNodeId": "guid",
      "destinationNodeId": "guid",
      "destinationPostalCode": "01001-000",
      "plannedDepartureAtUtc": "2026-06-10T20:30:00Z",
      "package": {
        "weightKg": 10.5,
        "cubicWeightKg": 12.0,
        "isFragile": false,
        "isRestricted": false,
        "category": "electronics"
      }
    }
  ]
}
```

`ShippingPromiseService` envia todos os campos acima, exceto `checkId`.

**Impacto provável:** `CarrierService` retorna erro de validação: `CheckId is required`.

**Correção recomendada:** gerar `checkId` determinístico por candidato, por exemplo:

```text
{routeId}:{carrierCode}:{serviceLevelCode}
```

---

### 4. ShippingPromiseService -> ShippingPricingService

**Rota:** OK.

```http
POST /shipping-prices/quotes/batch
```

**Request:** incompatível.

`ShippingPricingService` espera:

```json
{
  "buyerId": "guid",
  "sellerId": "guid",
  "destinationPostalCode": "01310-100",
  "cartTotal": 199.90,
  "currency": "BRL",
  "requestedAtUtc": "2026-06-14T00:00:00Z",
  "candidates": [
    {
      "candidateId": "route-1",
      "routeId": "route-1",
      "originNodeId": "guid",
      "carrierCode": "MELI-LOGISTICS",
      "serviceLevelCode": "EXPRESS",
      "package": {
        "actualWeightKg": 1.2,
        "cubicWeightKg": 1.0,
        "isFragile": false,
        "isRestricted": false,
        "category": "electronics"
      }
    }
  ]
}
```

`ShippingPromiseService` envia:

```json
{
  "quotes": [
    {
      "candidateId": "route-1",
      "routeId": "route-1",
      "originNodeId": "guid",
      "carrierCode": "MELI-LOGISTICS",
      "serviceLevelCode": "EXPRESS",
      "mode": "Fulfillment",
      "package": {
        "weightKg": 1.2,
        "cubicWeightKg": 1.0,
        "isFragile": false,
        "isRestricted": false
      }
    }
  ]
}
```

Diferenças:

| Campo | Status |
|---|---|
| `buyerId` | ausente |
| `sellerId` | ausente |
| `destinationPostalCode` | ausente |
| `cartTotal` | ausente |
| `currency` | ausente |
| `candidates` | client envia `quotes` |
| `package.actualWeightKg` | client envia `package.weightKg` |
| `category` | ausente |

**Response:** também incompatível.

`ShippingPricingService` retorna:

```json
{
  "quotes": [
    {
      "customerPrice": 22.99,
      "logisticsCost": 32.99,
      "discount": 5.00
    }
  ]
}
```

`ShippingPromiseService` tenta ler:

```csharp
PricingQuote(decimal Cost, decimal? Discount)
```

**Impacto provável:** preço incorreto, `Cost = 0`, ou indisponibilidade dependendo da validação do Pricing.

**Correção recomendada:** alterar `IPricingClient.GetPriceAsync` para receber contexto de buyer/seller/destino/cartTotal/currency e mapear `customerPrice` como preço ao cliente.

---

### 5. MarketplaceWeb.Bff -> TrackingService

**BFF chama:**

```http
GET /shipments/{shipmentId}/tracking
```

**TrackingService expõe:**

```http
GET /tracking/shipments/{shipmentId}
```

**Status:** incompatível.

**Correção recomendada:** no `TrackingClient`, trocar para:

```csharp
httpClient.GetAsync($"/tracking/shipments/{shipmentId}", cancellationToken)
```

---

### 6. MarketplaceWeb.Bff -> OrderService - listagem

**BFF chama:**

```http
GET /orders
```

**OrderService expõe atualmente:**

```http
GET /orders/{orderId}
POST /orders/{orderId}/cancel
```

**Status:** incompatível.

**Correção recomendada:** escolher uma opção:

1. Implementar `GET /orders` no `OrderService` retornando `OrderListDto`; ou
2. Remover/alterar `GET /api/web/v1/orders/` no BFF se a tela de listagem não for necessária.

---

### 7. MarketplaceWeb.Bff -> OrderService - cancelamento

**BFF expõe:**

```http
POST /api/web/v1/orders/{orderId}/cancel
```

mas não recebe body e chama downstream sem body.

**OrderService exige:**

```json
{
  "reason": "Solicitação do comprador"
}
```

Além disso:

- `OrderService` retorna `202 Accepted` sem body.
- `BFF` tenta desserializar `OrderDto` no retorno.
- `BFF` retorna `200 OK` com body.

**Status:** incompatível.

**Correção recomendada:** alinhar contrato. Sugestão:

- BFF recebe `CancelOrderRequest` com `reason`.
- BFF repassa body ao `OrderService`.
- BFF retorna `202 Accepted` sem tentar desserializar body.

---

### 8. MarketplaceWeb.Bff -> ShipmentService - label

**BFF espera downstream binário/PDF:**

```http
GET /shipments/{shipmentId}/label
Accept: application/pdf
```

**ShipmentService retorna JSON:**

```json
{
  "url": "https://shipment.local/labels/...pdf",
  "expiresInSeconds": 300
}
```

**Status:** incompatível.

**Correção recomendada:** escolher uma opção:

1. Alterar BFF para retornar/redirect para a URL assinada; ou
2. Alterar `ShipmentService` para retornar `application/pdf` binário.

Para arquitetura de cloud/storage, a opção 1 é mais natural: BFF retorna JSON com `url` e `expiresInSeconds`, ou responde `302 Redirect`.

---

## Contratos serviço-dono validados

Os endpoints abaixo estão consistentes com os respectivos serviços donos:

| Serviço | Endpoints validados |
|---|---|
| ProductSearchService | `GET /v1/products/search` |
| ProductCatalogService | `POST /products/`, `GET /products/{skuId}`, `POST /products/physical-info/batch`, `PUT /products/{skuId}/physical-info`, `PATCH /products/{skuId}/status` |
| CheckoutService | `POST /checkouts`, `GET /checkouts/{checkoutId}`, `POST /checkouts/{checkoutId}/confirm` |
| InventoryService | `POST /inventory/availability/batch`, `GET /inventory/{sellerId}/{skuId}`, reservas e ajustes |
| FulfillmentCenterService | `POST /fulfillment-centers/candidates/search`, capacidade, status e reservas |
| RoutingService | `POST /routes/search`, `/network/*` |
| CarrierService | `/carriers/*`, `POST /carrier-availability/search` |
| ShippingPricingService | `POST /shipping-prices/quotes/batch`, `GET /shipping-prices/quotes/{quoteId}` |
| OrderService | `GET /orders/{orderId}`, `POST /orders/{orderId}/cancel` |
| ShipmentService | `GET /shipments/{shipmentId}`, `GET /shipments/{shipmentId}/label`, `POST /shipments/{shipmentId}/cancel` |
| TrackingService | `GET /tracking/shipments/{shipmentId}`, `GET /tracking/{trackingCode}`, `GET /tracking/shipments/{shipmentId}/events` |
| NotificationService | `/notifications/*`, `/notification-preferences/*`, `/providers/*/receipts` |

## Próximas ações recomendadas

Prioridade sugerida:

1. Corrigir `ShippingPromiseService -> RoutingService`, porque impede montagem de candidatos.
2. Corrigir `ShippingPromiseService -> FulfillmentCenterService`, porque `HasCapacity` tende a ficar falso por ausência do campo.
3. Corrigir `ShippingPromiseService -> CarrierService`, adicionando `checkId`.
4. Corrigir `ShippingPromiseService -> ShippingPricingService`, ajustando request e response.
5. Corrigir `MarketplaceWeb.Bff -> TrackingService`.
6. Corrigir `MarketplaceWeb.Bff -> OrderService` para listagem e cancelamento.
7. Corrigir `MarketplaceWeb.Bff -> ShipmentService` para label JSON/redirect ou PDF binário.

## Decisão de contrato

A regra continua a mesma:

> O contrato canônico é sempre o contrato do serviço dono da API. Clients consumidores devem se adaptar ao serviço dono, e não o contrário.
