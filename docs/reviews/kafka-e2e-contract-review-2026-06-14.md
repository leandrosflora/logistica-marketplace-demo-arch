# Revisão de contratos Kafka E2E - Microservices Meli Envios

Data: 2026-06-14

## Escopo

Validação estática das modificações Kafka recentes nos microservices e revisão de aderência ao repositório `meli-envios-architecture`.

Repos avaliados:

- `leandrosflora/CheckoutService`
- `leandrosflora/ShippingPromiseService`
- `leandrosflora/OrderService`
- `leandrosflora/ShipmentService`
- `leandrosflora/TrackingService`
- `leandrosflora/NotificationService`
- `leandrosflora/meli-envios-architecture`

## Resultado executivo

Status: **não pronto para E2E Kafka completo**.

As integrações Kafka reais foram implementadas nos principais serviços, mas há desalinhamento de payload entre producers e consumers.

O broker, os nomes de tópicos e os consumer groups estão majoritariamente corretos. O bloqueio está no contrato dos eventos.

## Validação por fluxo

### 1. CheckoutService -> ShippingPromiseService

Tópico esperado:

```text
checkout.shipping.quote.requested
```

Status: **parcial**.

O `CheckoutService` publica `checkout.shipping.quote.requested`.

Problema:

- Não foi encontrada implementação de consumer Kafka no `ShippingPromiseService` para `checkout.shipping.quote.requested`.
- O `ShippingPromiseService` continua publicando `shipping.promise.calculated` após cálculo HTTP síncrono.

Impacto:

- O fluxo assíncrono `checkout.shipping.quote.requested -> shipping.promise.calculated` ainda não fecha por Kafka.
- Para E2E completo, o `ShippingPromiseService` precisa consumir `checkout.shipping.quote.requested` ou o runbook deve deixar claro que a fase de promise ainda depende de chamada HTTP.

### 2. ShippingPromiseService -> CheckoutService

Tópico:

```text
shipping.promise.calculated
```

Status: **quebrado por contrato**.

O `CheckoutService` espera `checkoutId` no payload de `shipping.promise.calculated` para idempotência e projeção local.

O `ShippingPromiseService` publica `shipping.promise.calculated` com `buyerId`, `sellerId`, `destination`, `items`, `promiseId`, `mode`, `carrier`, `estimatedDeliveryDate`, `cost` e `source`, mas sem `checkoutId`.

Impacto:

- O consumer do `CheckoutService` tende a registrar `Guid.Empty` como `checkoutId` ou falhar semanticamente.
- A projeção `ShippingPromiseProjection` não consegue associar corretamente a promise ao checkout.

Correção recomendada:

- Incluir `checkoutId` no request/evento de promise.
- Propagar `checkoutId` desde `checkout.shipping.quote.requested` até `shipping.promise.calculated`.

### 3. OrderService -> ShipmentService

Tópico:

```text
order.created
```

Status: **quebrado por contrato**.

O `OrderService` publica payload reduzido:

- `messageId`
- `orderId`
- `checkoutId`
- `buyerId`
- `sellerId`
- `totalAmount`
- `currency`
- `createdAt`

O `ShipmentService` consome `order.created` esperando campos logísticos adicionais:

- `shippingPromiseId`
- `routeId`
- `carrierCode`
- `serviceLevelCode`
- `originNodeId`
- `promisedDeliveryDate`
- `destination`
- `packages`

Impacto:

- O `ShipmentService` não tem dados suficientes para criar shipment a partir do evento real publicado pelo `OrderService`.
- O E2E `order.created -> shipment.created` não deve funcionar corretamente sem ajuste.

Correções possíveis:

1. Enriquecer `order.created` com os dados logísticos necessários ao `ShipmentService`.
2. Alterar o fluxo para o `ShipmentService` consumir um comando interno de saga, como `shipment.commands`, em vez de consumir `order.created` diretamente.
3. Criar um evento canônico intermediário mais explícito, como `shipment.requested`, emitido pelo `OrderService` após validação da saga.

Recomendação arquitetural: **usar `shipment.commands` ou `shipment.requested` para criação de shipment**, mantendo `order.created` como fato de domínio mais limpo.

### 4. ShipmentService -> TrackingService

Tópico:

```text
shipment.created
```

Status: **parcial**.

O `ShipmentService` publica `shipment.created` com campos próximos do necessário para o `TrackingService`.

Problemas:

- `TrackingService` espera `estimatedDeliveryDate`, mas `ShipmentService` publica `promisedDeliveryDate`.
- `TrackingService` espera `createdAt`, mas `ShipmentService` publica `occurredAt` dentro do payload e também `occurredAt` no envelope.
- `ShipmentService` publica `trackingCode` como `string.Empty` no momento da criação.

Impacto:

- O consumer pode desserializar, mas com campos importantes vazios/nulos.
- A geração do primeiro status de tracking pode ocorrer com `trackingCode` vazio.

Correção recomendada:

- Padronizar nomes no contrato canônico: `estimatedDeliveryDate` e `createdAt`.
- Garantir tracking code real quando disponível ou declarar explicitamente que `trackingCode` pode ser nulo no evento inicial.

### 5. TrackingService -> OrderService / NotificationService

Tópico:

```text
shipment.status.updated
```

Status: **quebrado por contrato**.

O `TrackingService` publica o payload com base em `TrackingStatusChangedIntegrationEvent`, contendo:

- `messageId`
- `correlationId`
- `shipmentId`
- `trackingCode`
- `carrierCode`
- `previousStatus`
- `currentStatus`
- `location`
- `occurredAt`
- `estimatedDeliveryDate`
- `exceptionCode`

O `OrderService` consome `shipment.status.updated` esperando:

- `orderId`
- `shipmentId`
- `status`
- `updatedAt`

O `NotificationService` consome `shipment.status.updated` esperando:

- `shipmentId`
- `buyerId`
- `trackingCode`
- `currentStatus`
- `estimatedDeliveryDate`
- `exceptionCode`

Problemas:

- O payload publicado pelo `TrackingService` não tem `orderId`.
- O payload publicado pelo `TrackingService` não tem `buyerId`.
- O `OrderService` espera `status`, mas o producer publica `currentStatus`.
- O `OrderService` espera `updatedAt`, mas o producer publica `occurredAt`.

Impacto:

- `OrderService` não consegue atualizar o pedido corretamente.
- `NotificationService` não consegue identificar o comprador para notificação.

Correção recomendada:

- Propagar `orderId` e `buyerId` desde `shipment.created` para o `TrackingService`.
- Padronizar `shipment.status.updated` com `orderId`, `buyerId`, `shipmentId`, `trackingCode`, `previousStatus`, `currentStatus`, `statusDate`, `estimatedDeliveryDate` e `exceptionCode`.

## Pontos positivos

- Os tópicos canônicos estão convergindo para a arquitetura:
  - `checkout.shipping.quote.requested`
  - `shipping.promise.calculated`
  - `order.created`
  - `shipment.created`
  - `shipment.status.updated`
- As integrações usam envelope Kafka com `eventId`, `eventType`, `schemaVersion`, `occurredAt`, `correlationId`, `producer` e `payload`.
- Os serviços usam `localhost:9092` para desenvolvimento local.
- Foi corrigido o commit de offset no `TrackingService`.
- O `OrderService` teve seus tópicos internos de saga formalizados por ADR.

## Bloqueios atuais

| Severidade | Bloqueio | Impacto |
|---|---|---|
| Alta | `order.created` produzido pelo `OrderService` não atende o contrato esperado pelo `ShipmentService` | Quebra criação de shipment no E2E |
| Alta | `shipment.status.updated` produzido pelo `TrackingService` não atende `OrderService` e `NotificationService` | Quebra atualização de pedido e notificação |
| Alta | `shipping.promise.calculated` não contém `checkoutId` | Quebra projeção no `CheckoutService` |
| Média | `ShippingPromiseService` não consome `checkout.shipping.quote.requested` | Fluxo quote/promise ainda não é assíncrono completo |
| Média | `CheckoutService` consome promise apenas no modo DB-backed | Em mock mode, o fluxo Kafka de retorno não fecha |
| Média | Serviços ainda dependem de DB/Inbox/Outbox reais | E2E local exige schema aplicado |

## Decisão recomendada

Antes de rodar E2E local completo, alinhar contratos canônicos no `kafka-events.md` e depois ajustar os producers/consumers.

Ordem sugerida:

1. Definir contrato canônico final no `kafka-events.md`.
2. Corrigir `ShippingPromiseService` para incluir `checkoutId` em `shipping.promise.calculated`.
3. Corrigir o fluxo `OrderService -> ShipmentService` decidindo entre:
   - enriquecer `order.created`; ou
   - trocar criação de shipment para comando interno `shipment.commands`; ou
   - criar `shipment.requested`.
4. Corrigir `shipment.created` para carregar `orderId` e `buyerId` até o `TrackingService`.
5. Corrigir `shipment.status.updated` para incluir `orderId`, `buyerId`, `currentStatus` e `statusDate`.
6. Atualizar runbook e payloads de exemplo.
7. Executar `dotnet restore`, `dotnet build`, `dotnet test` em todos os microservices.
8. Executar E2E com Kafka local.

## Parecer final

As modificações nos microservices estão bem encaminhadas em infraestrutura Kafka, mas ainda não fecham o E2E porque cada serviço criou seu próprio payload local.

O próximo passo não é mexer em Docker ou Kafka. É **contrato compartilhado**.
