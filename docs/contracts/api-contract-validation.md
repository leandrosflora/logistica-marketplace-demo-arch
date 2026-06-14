# Validação de contratos HTTP - Meli Envios

Data da validação: 2026-06-14

## Objetivo

Validar os contratos HTTP dos repositórios envolvidos no case Meli Envios e consolidar uma visão canônica em OpenAPI.

Arquivo OpenAPI consolidado gerado:

- [`docs/contracts/meli-envios-apis.openapi.yaml`](meli-envios-apis.openapi.yaml)

## Repositórios avaliados

| Componente | Status | Observação |
|---|---|---|
| MarketplaceWeb | Não aplicável | Frontend Razor/Web; não expõe API HTTP própria para outros serviços. |
| MarketplaceWeb.Bff | Validado | README expõe endpoints em `/api/web/v1`. |
| CheckoutService | Validado | README expõe criação, consulta e confirmação de checkout. |
| ProductCatalogService | Validado | README expõe CRUD parcial de produto e batch de informações físicas. |
| ProductSearchService | Validado | README expõe busca textual paginada em `/v1/products/search`. |
| ShippingPromiseService | Validado com divergências | Contrato próprio está claro, mas integrações downstream estão desalinhadas com serviços reais. |
| InventoryService | Validado | README expõe disponibilidade, reservas e ajustes. |
| FulfillmentCenterService | Validado | README expõe candidatos, capacidade, status e reservas. |
| RoutingService | Validado | README expõe busca de rotas e administração de rede logística. |
| CarrierService | Validado | README expõe cadastro, status, lanes, níveis de serviço e availability em lote. |
| ShippingPricingService | Validado | README expõe cotação batch e rate cards. |
| OrderService | Validado | README expõe consulta e cancelamento de pedido. |
| ShipmentService | Validado | README expõe consulta, etiqueta e cancelamento de remessa. |
| TrackingService | Validado | README expõe consulta de tracking e histórico de eventos. |
| NotificationService | Validado | README expõe consulta, evento de tracking, preferências e receipts. |

## Resultado geral

Os contratos públicos principais foram consolidados no arquivo OpenAPI canônico. O maior ponto de atenção está no **ShippingPromiseService**, porque ele documenta chamadas downstream com rotas/payloads diferentes das APIs reais dos serviços especialistas.

## Divergências encontradas

### 1. ShippingPromiseService -> InventoryService

**ShippingPromiseService documenta:**

```http
POST /inventory/availability
```

**InventoryService expõe:**

```http
POST /inventory/availability/batch
```

**Decisão no OpenAPI canônico:** usar `/inventory/availability/batch`.

**Ação recomendada:** ajustar o client/README do `ShippingPromiseService` para usar o endpoint real do `InventoryService`.

---

### 2. ShippingPromiseService -> FulfillmentCenterService

**ShippingPromiseService documenta:**

```http
POST /fulfillment/candidates
```

**FulfillmentCenterService expõe:**

```http
POST /fulfillment-centers/candidates/search
```

**Decisão no OpenAPI canônico:** usar `/fulfillment-centers/candidates/search`.

**Ação recomendada:** ajustar o client/README do `ShippingPromiseService` para chamar o endpoint real e adaptar o payload para `destinationPostalCode`, `mode`, `package` e `requestedAtUtc`.

---

### 3. ShippingPromiseService -> RoutingService

**ShippingPromiseService documenta request com:**

```json
{
  "originFulfillmentCenterId": "...",
  "destination": {
    "zipCode": "01310-100",
    "city": "São Paulo",
    "state": "SP",
    "country": "BR"
  },
  "package": {
    "totalWeightKg": 1.2,
    "cubicWeightKg": 1.0,
    "heightCm": 10,
    "widthCm": 20,
    "lengthCm": 30,
    "hasFragileItem": false,
    "hasRestrictedItem": false
  }
}
```

**RoutingService expõe request com:**

```json
{
  "originNodeId": "...",
  "destinationPostalCode": "01310-100",
  "package": {
    "weightKg": 2.5,
    "cubicWeightKg": 3.1,
    "isFragile": false,
    "isRestricted": false
  },
  "requestedAtUtc": "2026-06-10T12:00:00Z",
  "maxOptions": 3
}
```

**Decisão no OpenAPI canônico:** usar o contrato real do `RoutingService`.

**Ação recomendada:** criar adapter no `ShippingPromiseService` para converter fulfillment center em `originNodeId`, endereço em `destinationPostalCode` e pacote interno para `PackageProfile` do Routing.

---

### 4. ShippingPromiseService -> CarrierService

**ShippingPromiseService documenta:**

```http
POST /carriers/availability
```

**CarrierService expõe:**

```http
POST /carrier-availability/search
```

**Decisão no OpenAPI canônico:** usar `/carrier-availability/search`.

**Ação recomendada:** ajustar `ShippingPromiseService` para montar checks em lote com `carrierCode`, `serviceLevelCode`, `originNodeId`, `destinationNodeId`, `destinationPostalCode`, `plannedDepartureAtUtc` e `package`.

---

### 5. ShippingPromiseService -> ShippingPricingService

**ShippingPromiseService documenta:**

```http
POST /shipping/prices/quote
```

**ShippingPricingService expõe:**

```http
POST /shipping-prices/quotes/batch
```

**Decisão no OpenAPI canônico:** usar `/shipping-prices/quotes/batch`.

**Ação recomendada:** ajustar `ShippingPromiseService` para enviar candidatos precificáveis em lote, usando `candidateId`, `routeId`, `originNodeId`, `carrierCode`, `serviceLevelCode` e `package`.

## Decisões de contrato adotadas

1. **OpenAPI canônico privilegia o contrato do serviço dono da API.**  
   Exemplo: para Inventory, vale o README/contrato do `InventoryService`, não o payload esperado por um client downstream.

2. **Campos adicionais em responses são considerados compatíveis.**  
   Exemplo: `ProductCatalogService` retorna `sellerId` e `status` em informações físicas. Isso é compatível mesmo que o consumidor use apenas peso, dimensão e flags logísticas.

3. **Rotas batch são preferidas para fluxo crítico de Shipping Promise.**  
   Inventory, Carrier e Pricing já possuem contratos mais adequados para cálculo de promessa em lote/candidatos.

4. **Frontend não recebeu OpenAPI próprio.**  
   `MarketplaceWeb` é consumidor web. O contrato externo relevante é o `MarketplaceWeb.Bff`.

## Próximas ações recomendadas

1. Atualizar os clients HTTP do `ShippingPromiseService` para os contratos canônicos.
2. Atualizar o README do `ShippingPromiseService` para remover rotas antigas.
3. Adicionar validação de contrato no CI usando `swagger-cli`, `redocly` ou `spectral`.
4. Opcionalmente quebrar o OpenAPI consolidado em arquivos por serviço quando a esteira de geração de contratos estiver madura.
