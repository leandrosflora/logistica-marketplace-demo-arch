# Prompts Codex - Correção de contratos Kafka E2E

Data: 2026-06-14

## Objetivo

Corrigir os microservices para fechar o E2E Kafka local com base no contrato canônico documentado em `meli-envios-architecture/docs/contracts/kafka-events.md`.

Problemas principais:

1. `OrderService -> ShipmentService`: `order.created` produzido não atende o payload esperado pelo `ShipmentService`.
2. `ShippingPromiseService -> CheckoutService`: `shipping.promise.calculated` não carrega `checkoutId`.
3. `TrackingService -> OrderService / NotificationService`: `shipment.status.updated` não carrega `orderId` e `buyerId`, e usa nomes incompatíveis para status/data.
4. `ShippingPromiseService` ainda não consome `checkout.shipping.quote.requested`.
5. `CheckoutService` precisa consumir `shipping.promise.calculated` também em modo mock/local ou documentar limitação explícita.

---

# Prompt para `leandrosflora/CheckoutService`

```text
Você está no repositório `leandrosflora/CheckoutService`.

Contexto:
Este microservice faz parte do case Meli Envios e precisa fechar o fluxo Kafka local E2E com o `ShippingPromiseService`.

Contrato canônico esperado:

Tópico produzido pelo CheckoutService:
- `checkout.shipping.quote.requested`

Envelope obrigatório:
{
  "eventId": "uuid",
  "eventType": "checkout.shipping.quote.requested",
  "schemaVersion": "1.0",
  "occurredAt": "2026-06-14T12:00:00Z",
  "correlationId": "uuid",
  "producer": "checkout-service",
  "payload": {}
}

Payload obrigatório de `checkout.shipping.quote.requested`:
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

Tópico consumido pelo CheckoutService:
- `shipping.promise.calculated`

Payload obrigatório de `shipping.promise.calculated`:
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

Tarefas:

1. Revisar `Contracts/KafkaEventContracts.cs` e garantir que:
   - `ShippingQuoteRequestedPayload` tenha `checkoutId`, `buyerId`, `sellerId`, `destination` e `items`.
   - `ShippingPromiseCalculatedPayload` tenha `checkoutId`, `buyerId`, `sellerId`, `promiseId`, `mode`, `carrier`, `estimatedDeliveryDate`, `cost`, `currency` e `source`.
   - Os nomes JSON sejam camelCase e compatíveis com o contrato acima.

2. Revisar `Application/CheckoutApplicationService.cs`:
   - Garantir que o evento `checkout.shipping.quote.requested` use o `checkout.Id` real como `checkoutId`.
   - Propagar `correlationId` corretamente.
   - Não publicar payload sem `checkoutId`.

3. Revisar `Infrastructure/Messaging/ShippingPromiseCalculatedConsumer.cs`:
   - Consumir `shipping.promise.calculated` usando `checkoutId` obrigatório.
   - Validar `eventType == "shipping.promise.calculated"`.
   - Ignorar/registrar erro para mensagens sem `checkoutId` válido.
   - Gravar a projeção usando `checkoutId`, `eventId` e `correlationId`.

4. Resolver limitação atual de mock mode:
   - Hoje o consumer de `shipping.promise.calculated` só roda em modo DB-backed.
   - Para E2E local, implemente uma das opções:
     a) criar `InMemoryShippingPromiseProjectionRepository` para `MockData:Enabled = true` e registrar o consumer também em mock mode; ou
     b) documentar explicitamente que o fluxo de retorno da promise exige DB-backed e ajustar README/runbook.
   - Preferência: implementar a opção (a), porque o objetivo é E2E local simples.

5. Revisar `Program.cs`:
   - Garantir que `KafkaOptions` seja configurado em qualquer modo.
   - Se Kafka estiver configurado, registrar producer e consumer.
   - Em mock mode, usar `KafkaEventPublisher` para producer e `InMemoryShippingPromiseProjectionRepository` para consumer.
   - Em DB-backed, manter Outbox + `OutboxKafkaDispatcher` + `ShippingPromiseProjectionRepository`.

6. Atualizar README com:
   - tópicos usados;
   - exemplo de payload `checkout.shipping.quote.requested`;
   - exemplo de payload `shipping.promise.calculated`;
   - observação sobre `checkoutId` obrigatório.

7. Executar:
   - `dotnet restore`
   - `dotnet build`
   - `dotnet test`

Critérios de aceite:

- `checkout.shipping.quote.requested` sempre publica `checkoutId` real.
- `shipping.promise.calculated` é consumido com `checkoutId` obrigatório.
- Consumer funciona em modo local mock ou README documenta claramente a exigência de DB-backed.
- Build e testes passam.
```

---

# Prompt para `leandrosflora/ShippingPromiseService`

```text
Você está no repositório `leandrosflora/ShippingPromiseService`.

Contexto:
Este microservice precisa fechar o fluxo assíncrono Kafka com o `CheckoutService`.

Problemas atuais:
1. O serviço publica `shipping.promise.calculated`, mas o payload não contém `checkoutId`.
2. O serviço ainda não consome `checkout.shipping.quote.requested`.
3. O fluxo `checkout.shipping.quote.requested -> shipping.promise.calculated` ainda não é totalmente assíncrono por Kafka.

Contrato canônico esperado:

Consumer:
- tópico: `checkout.shipping.quote.requested`
- eventType: `checkout.shipping.quote.requested`

Payload recebido:
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

Producer:
- tópico: `shipping.promise.calculated`
- eventType: `shipping.promise.calculated`

Payload publicado:
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

Tarefas:

1. Criar contrato de entrada Kafka:
   - `KafkaEventEnvelope<TPayload>` se já não existir.
   - `ShippingQuoteRequestedPayload` com `checkoutId`, `buyerId`, `sellerId`, `destination` e `items`.

2. Atualizar `ShippingPromiseCalculatedPayload`:
   - adicionar `CheckoutId`.
   - adicionar `Currency`, se ainda não existir.
   - garantir nomes JSON camelCase compatíveis com o contrato.

3. Atualizar `IShippingPromiseEventPublisher.PublishCalculatedAsync`:
   - incluir `checkoutId` como parâmetro ou carregar `checkoutId` dentro do request.
   - garantir que o evento publicado contenha `checkoutId`.

4. Atualizar o modelo/request da aplicação:
   - Se `ShippingPromiseRequest` ainda não tiver `CheckoutId`, adicionar `Guid? CheckoutId` ou `Guid CheckoutId` conforme melhor compatibilidade.
   - Para chamadas HTTP síncronas sem checkoutId, manter compatibilidade usando `Guid.Empty` somente se não houver alternativa, mas para fluxo Kafka o `checkoutId` deve ser obrigatório.
   - Preferência: criar um command interno específico para Kafka, evitando quebrar API HTTP pública.

5. Implementar consumer Kafka:
   - Criar `ShippingQuoteRequestedConsumer : BackgroundService`.
   - Consumir `checkout.shipping.quote.requested`.
   - Validar `eventType`.
   - Desserializar payload.
   - Mapear para `ShippingPromiseRequest` ou command equivalente.
   - Chamar `ShippingPromiseApplicationService.CalculateAsync` com `correlationId` do envelope.
   - Publicar `shipping.promise.calculated` com o mesmo `checkoutId`.
   - Commit manual do offset somente após processamento bem-sucedido.
   - Em caso de payload inválido, logar erro estruturado e decidir se commita ou reprocessa; para E2E local, pode commitar payload inválido após log para não travar partição.

6. Atualizar `Program.cs`:
   - Registrar o consumer `ShippingQuoteRequestedConsumer` como hosted service.
   - Garantir `KafkaOptions` com tópicos:
     - `ShippingQuoteRequested = checkout.shipping.quote.requested`
     - `ShippingPromiseCalculated = shipping.promise.calculated`

7. Ajustar comportamento de cache:
   - Se a promise vier de cache mas a entrada veio de Kafka, ainda assim deve publicar `shipping.promise.calculated`, porque o checkout precisa receber a resposta assíncrona.
   - Evitar duplicidade usando eventId/correlationId quando necessário.

8. Atualizar README:
   - documentar consumer `checkout.shipping.quote.requested`;
   - documentar producer `shipping.promise.calculated`;
   - incluir payloads de exemplo;
   - explicar propagação de `checkoutId` e `correlationId`.

9. Executar:
   - `dotnet restore`
   - `dotnet build`
   - `dotnet test`

Critérios de aceite:

- Serviço consome `checkout.shipping.quote.requested`.
- Serviço publica `shipping.promise.calculated` com `checkoutId` obrigatório.
- `CheckoutService` consegue associar a promise ao checkout.
- Build e testes passam.
```

---

# Prompt para `leandrosflora/OrderService`

```text
Você está no repositório `leandrosflora/OrderService`.

Contexto:
O `OrderService` publica `order.created`, mas o payload atual é reduzido e não atende o `ShipmentService` no E2E Kafka.

Contrato canônico esperado para `order.created` no E2E atual:

Envelope:
{
  "eventId": "uuid",
  "eventType": "order.created",
  "schemaVersion": "1.0",
  "occurredAt": "2026-06-14T12:00:00Z",
  "correlationId": "uuid",
  "producer": "order-service",
  "payload": {}
}

Payload:
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

Tarefas:

1. Revisar `Contracts/IntegrationEvents.cs`:
   - Expandir `OrderCreatedIntegrationEvent` para conter todos os campos acima.
   - Criar DTOs necessários: destination, packages e package items.
   - Garantir serialização camelCase no envelope.

2. Revisar `Application/OrderProcessManager.cs`:
   - Ao publicar `order.created`, preencher o payload canônico completo.
   - Reaproveitar dados existentes do `CheckoutConfirmedIntegrationEvent` quando disponíveis.
   - O que não existir no evento de entrada deve ser tratado explicitamente:
     - Se for obrigatório para E2E local, criar valores derivados ou defaults controlados apenas em modo Development/Mock.
     - Não usar `string.Empty` silencioso para campos obrigatórios sem log.

3. Revisar `CheckoutConfirmedIntegrationEvent`:
   - Se ele não tiver dados necessários para shipment, estender o contrato de entrada com:
     - `routeId`
     - `carrierCode`
     - `serviceLevelCode`
     - `originNodeId`
     - `promisedDeliveryDate`
     - `destination`
     - `packages`
   - Garantir compatibilidade com testes e mocks existentes.

4. Alternativa arquitetural aceitável:
   - Se concluir que `order.created` não deve ser enriquecido com dados logísticos, então implemente `shipment.commands` como comando interno para criação de shipment e mantenha `order.created` limpo.
   - Nesse caso, documente no README que `ShipmentService` deve consumir `shipment.commands`, não `order.created`, para criação física da entrega.
   - Para este ajuste, a preferência do contrato atual é enriquecer `order.created` para fechar o E2E, mas registre a decisão técnica no README.

5. Corrigir consumo de `shipment.status.updated`:
   - O novo payload canônico esperado tem:
     - `shipmentId`
     - `orderId`
     - `buyerId`
     - `trackingCode`
     - `carrierCode`
     - `previousStatus`
     - `currentStatus`
     - `statusDate`
     - `estimatedDeliveryDate`
     - `exceptionCode`
   - Atualizar `ShipmentStatusUpdatedIntegrationEvent` para usar `CurrentStatus` e `StatusDate`, ou mapear explicitamente para o modelo interno esperado.
   - Não esperar mais `status` e `updatedAt` se o produtor usa `currentStatus` e `statusDate`.

6. Atualizar `Infrastructure/Messaging/ShipmentStatusUpdatedConsumer.cs`:
   - Validar `eventType == "shipment.status.updated"`.
   - Desserializar o payload novo.
   - Atualizar pedido por `orderId`.
   - Manter idempotência por `eventId`.

7. Atualizar schema se necessário:
   - Se novos campos forem persistidos, atualizar `schema.sql` e mappings EF Core.

8. Atualizar README:
   - documentar payload completo de `order.created`;
   - documentar payload consumido de `shipment.status.updated`;
   - explicar dependência com `ShipmentService` e `TrackingService`.

9. Executar:
   - `dotnet restore`
   - `dotnet build`
   - `dotnet test`

Critérios de aceite:

- `OrderService` publica `order.created` com payload suficiente para o `ShipmentService` criar a entrega.
- `OrderService` consome `shipment.status.updated` no contrato canônico novo.
- Build e testes passam.
```

---

# Prompt para `leandrosflora/ShipmentService`

```text
Você está no repositório `leandrosflora/ShipmentService`.

Contexto:
O `ShipmentService` consome `order.created` e publica `shipment.created`, mas os contratos precisam ser alinhados com os demais serviços.

Contrato canônico esperado de entrada: `order.created`.

Payload:
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

Contrato canônico esperado de saída: `shipment.created`.

Payload:
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

Tarefas:

1. Atualizar contrato de entrada `OrderCreatedIntegrationEvent`:
   - Garantir que os campos estejam alinhados ao payload canônico.
   - Manter tolerância para campos extras.
   - Falhar com log claro se campos obrigatórios para criar shipment vierem ausentes.

2. Atualizar `OrderCreatedKafkaConsumer`:
   - Validar `eventType == "order.created"`.
   - Mapear corretamente os campos para `CreateShipmentCommand`.
   - Usar `envelope.EventId` para idempotência.
   - Propagar `envelope.CorrelationId`.

3. Atualizar `CreateShipmentCommand`, se necessário:
   - Incluir `BuyerId`, caso ainda não esteja garantido.
   - Garantir `OrderId`, `ShippingPromiseId`, `RouteId`, `CarrierCode`, `ServiceLevelCode`, `OriginNodeId`, `PromisedDeliveryDate`, `Destination` e `Packages`.

4. Atualizar `ShipmentCreationHandler`:
   - Ao publicar `shipment.created`, incluir `buyerId` no payload.
   - Usar nomes canônicos:
     - `estimatedDeliveryDate`, não apenas `promisedDeliveryDate`.
     - `createdAt`, não apenas `occurredAt`.
   - Evitar publicar `trackingCode` como `string.Empty` se ele for obrigatório para downstream.
   - Se tracking code ainda não existir no momento da criação, tornar `trackingCode` nullable no contrato ou preencher com valor real do booking quando disponível.
   - Para E2E local, se o booking externo for mockado, gerar um tracking code determinístico, por exemplo `TRACK-{shipmentId:N}`.

5. Atualizar `ShipmentCreatedIntegrationEvent`:
   - Campos obrigatórios:
     - `shipmentId`
     - `orderId`
     - `buyerId`
     - `carrierCode`
     - `serviceLevelCode`
     - `externalShipmentId`
     - `trackingCode`
     - `labelObjectKey`
     - `estimatedDeliveryDate`
     - `createdAt`

6. Atualizar README:
   - Documentar payload de entrada `order.created`.
   - Documentar payload de saída `shipment.created`.
   - Explicar que `buyerId` precisa ser propagado para notificação.

7. Executar:
   - `dotnet restore`
   - `dotnet build`
   - `dotnet test`

Critérios de aceite:

- `ShipmentService` consegue criar shipment a partir do `order.created` canônico.
- `shipment.created` carrega `orderId` e `buyerId`.
- `TrackingService` e `NotificationService` conseguem consumir o evento sem lookup adicional obrigatório.
- Build e testes passam.
```

---

# Prompt para `leandrosflora/TrackingService`

```text
Você está no repositório `leandrosflora/TrackingService`.

Contexto:
O `TrackingService` consome `shipment.created` e publica `shipment.status.updated`. O contrato atual publicado não atende `OrderService` e `NotificationService` porque não carrega `orderId` e `buyerId`.

Contrato canônico de entrada: `shipment.created`.

Payload esperado:
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

Contrato canônico de saída: `shipment.status.updated`.

Payload esperado:
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

Tarefas:

1. Atualizar `ShipmentCreatedIntegrationEvent`:
   - Adicionar `OrderId`.
   - Adicionar `BuyerId`.
   - Padronizar `EstimatedDeliveryDate`.
   - Padronizar `CreatedAt`.
   - Manter `ShipmentId`, `TrackingCode`, `CarrierCode`.

2. Atualizar `KafkaTrackingMessageConsumer`:
   - Desserializar o novo payload de `shipment.created`.
   - Propagar `orderId` e `buyerId` para o evento interno de tracking.
   - Preservar `correlationId` do envelope.
   - Validar `eventType == "shipment.created"`.

3. Atualizar evento interno `CarrierTrackingEventIntegrationEvent` se necessário:
   - Incluir `OrderId`.
   - Incluir `BuyerId`.
   - Garantir que esses campos cheguem ao handler e ao Outbox.

4. Atualizar `TrackingStatusChangedIntegrationEvent`:
   - Incluir `OrderId`.
   - Incluir `BuyerId`.
   - Usar `CurrentStatus` e `PreviousStatus`.
   - Usar `StatusDate` como nome de saída canônico, ou mapear `OccurredAt` para `statusDate` na publicação Kafka.

5. Atualizar `KafkaIntegrationEventBus`:
   - Ao publicar `shipment.status.updated`, montar envelope canônico.
   - O payload publicado deve conter:
     - `shipmentId`
     - `orderId`
     - `buyerId`
     - `trackingCode`
     - `carrierCode`
     - `previousStatus`
     - `currentStatus`
     - `statusDate`
     - `estimatedDeliveryDate`
     - `exceptionCode`
   - Não publicar apenas o DTO interno se ele não estiver no contrato canônico.

6. Atualizar persistência se o domínio/projeção de tracking precisar guardar `orderId` e `buyerId`.
   - Atualizar EF mappings e `schema.sql`, se aplicável.

7. Atualizar README:
   - documentar entrada `shipment.created`.
   - documentar saída `shipment.status.updated`.
   - explicar por que `orderId` e `buyerId` são obrigatórios para `OrderService` e `NotificationService`.

8. Executar:
   - `dotnet restore`
   - `dotnet build`
   - `dotnet test`

Critérios de aceite:

- `TrackingService` consome `shipment.created` com `orderId` e `buyerId`.
- `TrackingService` publica `shipment.status.updated` com `orderId` e `buyerId`.
- `OrderService` consegue atualizar pedido por `orderId`.
- `NotificationService` consegue planejar notificação por `buyerId`.
- Build e testes passam.
```

---

# Prompt para `leandrosflora/NotificationService`

```text
Você está no repositório `leandrosflora/NotificationService`.

Contexto:
O `NotificationService` consome eventos canônicos Kafka para planejar notificações. Ele precisa aceitar os contratos corrigidos de `order.created`, `shipment.created` e `shipment.status.updated`.

Contratos canônicos relevantes:

1. `order.created`
Payload mínimo necessário para notificação:
{
  "orderId": "uuid",
  "buyerId": "uuid",
  "createdAt": "2026-06-14T12:00:00Z"
}

2. `shipment.created`
Payload:
{
  "shipmentId": "uuid",
  "orderId": "uuid",
  "buyerId": "uuid",
  "trackingCode": "BR123456789",
  "estimatedDeliveryDate": "2026-06-15",
  "createdAt": "2026-06-14T12:00:00Z"
}

3. `shipment.status.updated`
Payload:
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

Tarefas:

1. Revisar `Contracts/CanonicalKafkaEvents.cs`:
   - `OrderCreatedPayload` deve aceitar `orderId`, `buyerId` e ignorar campos extras.
   - `ShipmentCreatedPayload` deve incluir `orderId`, `buyerId`, `trackingCode`, `estimatedDeliveryDate` e `createdAt`.
   - `ShipmentStatusUpdatedPayload` deve incluir `orderId`, `buyerId`, `shipmentId`, `trackingCode`, `carrierCode`, `previousStatus`, `currentStatus`, `statusDate`, `estimatedDeliveryDate` e `exceptionCode`.

2. Revisar `KafkaNotificationConsumer`:
   - Validar `eventType` igual ao tópico.
   - Desserializar os três payloads canônicos.
   - Manter tolerância para campos extras.
   - Logar erro claro para ausência de `buyerId`, pois notificação depende dele.

3. Revisar `NotificationPlanner`:
   - Para `order.created`, planejar notificação de pedido confirmado usando `buyerId` e `orderId`.
   - Para `shipment.created`, planejar notificação de entrega criada usando `buyerId`, `shipmentId`, `trackingCode` e `estimatedDeliveryDate`.
   - Para `shipment.status.updated`, planejar por `currentStatus`, usando `statusDate` como data do status.
   - Não depender de lookup externo para descobrir comprador quando `buyerId` vier no evento.

4. Garantir idempotência:
   - Usar `eventId` do envelope como chave de inbox.
   - Commitar offset somente após processamento persistido.

5. Atualizar README:
   - documentar contratos consumidos;
   - incluir exemplos de payload;
   - explicar campos obrigatórios.

6. Executar:
   - `dotnet restore`
   - `dotnet build`
   - `dotnet test`

Critérios de aceite:

- NotificationService consome os três eventos corrigidos.
- `buyerId` é usado diretamente para planejar notificação.
- Campos extras não quebram desserialização.
- Build e testes passam.
```

---

# Prompt opcional de validação final no repo `meli-envios-architecture`

```text
Você está no repositório `leandrosflora/meli-envios-architecture`.

Objetivo:
Atualizar documentação após correção dos microservices Kafka.

Tarefas:

1. Revisar `docs/contracts/kafka-events.md` e garantir que os payloads documentados batem com os microservices corrigidos.
2. Revisar `docs/runbooks/kafka-local-e2e.md` e remover qualquer item marcado como pendente que já tenha sido corrigido.
3. Atualizar `docs/reviews/kafka-e2e-contract-review-2026-06-14.md` com uma seção "Correções aplicadas".
4. Adicionar uma matriz final:
   - tópico;
   - producer;
   - consumers;
   - payload obrigatório;
   - status.
5. Validar comandos Docker/Kafka do runbook.

Critérios de aceite:

- Documentação reflete o estado real dos microservices.
- Runbook permite executar E2E local por fases.
- Contratos estão explícitos e sem ambiguidade.
```
