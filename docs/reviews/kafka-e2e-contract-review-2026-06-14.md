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

Referências:

- [`docs/contracts/kafka-events.md`](../contracts/kafka-events.md)
- [`docs/runbooks/kafka-local-e2e.md`](../runbooks/kafka-local-e2e.md)
- [`docs/adr/0001-order-service-internal-saga-topics.md`](../adr/0001-order-service-internal-saga-topics.md)

## Resultado executivo

Status: **pronto para validação E2E local por fases**.

As integrações Kafka reais foram implementadas e os principais payloads foram alinhados entre producers e consumers.

A revisão foi estática, baseada nos arquivos atuais dos repositórios. A validação final ainda deve executar `dotnet restore`, `dotnet build`, `dotnet test` e o runbook Kafka local.

## Correções aplicadas

### 1. `CheckoutService -> ShippingPromiseService`

Status: **corrigido**.

Correções observadas:

- `CheckoutService` publica `checkout.shipping.quote.requested` com `checkoutId`, `buyerId`, `sellerId`, `destination` e `items`.
- `ShippingPromiseService` passou a ter consumer Kafka para `checkout.shipping.quote.requested`.
- O consumer valida `eventType == checkout.shipping.quote.requested`.
- O consumer converte o payload recebido para `ShippingPromiseRequest` preservando `checkoutId` e `correlationId`.

Resultado esperado:

```text
CheckoutService -> checkout.shipping.quote.requested -> ShippingPromiseService
```

### 2. `ShippingPromiseService -> CheckoutService`

Status: **corrigido**.

Correções observadas:

- `ShippingPromiseCalculatedPayload` passou a incluir `checkoutId`.
- O payload publicado por `shipping.promise.calculated` contém `checkoutId`, `buyerId`, `sellerId`, `promiseId`, `mode`, `carrier`, `estimatedDeliveryDate`, `cost`, `currency` e `source`.
- `CheckoutService` consome `shipping.promise.calculated` usando `checkoutId` para idempotência e projeção.

Resultado esperado:

```text
ShippingPromiseService -> shipping.promise.calculated -> CheckoutService
```

### 3. `OrderService -> ShipmentService`

Status: **corrigido**.

Correções observadas:

- `OrderCreatedIntegrationEvent` do `OrderService` foi enriquecido.
- O evento agora contém os campos necessários para o `ShipmentService` criar a entrega:
  - `orderId`
  - `checkoutId`
  - `buyerId`
  - `sellerId`
  - `shippingPromiseId`
  - `routeId`
  - `carrierCode`
  - `serviceLevelCode`
  - `originNodeId`
  - `promisedDeliveryDate`
  - `destination`
  - `packages`
  - `totalAmount`
  - `currency`
  - `createdAt`
- O contrato de entrada do `ShipmentService` está alinhado com esse payload.

Resultado esperado:

```text
OrderService -> order.created -> ShipmentService
```

### 4. `ShipmentService -> TrackingService / NotificationService`

Status: **corrigido**.

Correções observadas:

- `ShipmentCreatedIntegrationEvent` passou a carregar `orderId` e `buyerId`.
- O contrato usa `estimatedDeliveryDate` e `createdAt`.
- O payload agora atende `TrackingService` e `NotificationService` sem lookup adicional obrigatório para identificar pedido/comprador.

Resultado esperado:

```text
ShipmentService -> shipment.created -> TrackingService / NotificationService
```

### 5. `TrackingService -> OrderService / NotificationService`

Status: **corrigido**.

Correções observadas:

- `TrackingStatusChangedIntegrationEvent` passou a carregar `orderId` e `buyerId`.
- O evento usa `currentStatus`, `previousStatus` e `statusDate`.
- O contrato atende:
  - `OrderService`, que precisa de `orderId` para atualizar status da entrega no pedido;
  - `NotificationService`, que precisa de `buyerId` para planejar comunicação.

Resultado esperado:

```text
TrackingService -> shipment.status.updated -> OrderService / NotificationService
```

## Matriz final

| Tópico | Producer | Consumers | Payload obrigatório | Status |
|---|---|---|---|---|
| `checkout.shipping.quote.requested` | `checkout-service` | `shipping-promise-service`, `audit-service`, `analytics` | `checkoutId`, `buyerId`, `sellerId`, `destination`, `items[]` | Alinhado |
| `shipping.promise.calculated` | `shipping-promise-service` | `checkout-service`, `audit-service`, `analytics` | `checkoutId`, `buyerId`, `sellerId`, `promiseId`, `mode`, `carrier`, `estimatedDeliveryDate`, `cost`, `currency`, `source` | Alinhado |
| `order.created` | `order-service` | `shipment-service`, `notification-service`, `audit-service` | `orderId`, `checkoutId`, `buyerId`, `sellerId`, `shippingPromiseId`, `routeId`, `carrierCode`, `serviceLevelCode`, `originNodeId`, `promisedDeliveryDate`, `destination`, `packages[]`, `totalAmount`, `currency`, `createdAt` | Alinhado |
| `shipment.created` | `shipment-service` | `tracking-service`, `notification-service`, `audit-service` | `shipmentId`, `orderId`, `buyerId`, `carrierCode`, `serviceLevelCode`, `externalShipmentId`, `trackingCode`, `labelObjectKey`, `estimatedDeliveryDate`, `createdAt` | Alinhado |
| `shipment.status.updated` | `tracking-service` | `notification-service`, `audit-service`, `order-service` | `shipmentId`, `orderId`, `buyerId`, `trackingCode`, `carrierCode`, `previousStatus`, `currentStatus`, `statusDate`, `estimatedDeliveryDate`, `exceptionCode` | Alinhado |

## Validação por fluxo

### Fase 1 - Promise assíncrona

Fluxo esperado:

```text
CheckoutService
  -> checkout.shipping.quote.requested
  -> ShippingPromiseService
  -> shipping.promise.calculated
  -> CheckoutService
```

Status: **pronto para validação local**.

Validações esperadas:

- `checkout.shipping.quote.requested` contém `checkoutId`.
- `shipping.promise.calculated` retorna o mesmo `checkoutId`.
- `CheckoutService` registra/projeta a promise recebida.

### Fase 2 - Pedido, shipment, tracking e notification

Fluxo esperado:

```text
OrderService
  -> order.created
  -> ShipmentService
  -> shipment.created
  -> TrackingService
  -> shipment.status.updated
  -> OrderService / NotificationService
```

Status: **pronto para validação local**.

Validações esperadas:

- `order.created` contém dados logísticos suficientes para o `ShipmentService`.
- `shipment.created` propaga `orderId` e `buyerId`.
- `shipment.status.updated` propaga `orderId` e `buyerId`.
- `OrderService` atualiza status de entrega do pedido.
- `NotificationService` planeja comunicação usando `buyerId`.

## Pontos positivos

- Os tópicos canônicos convergiram para o contrato de arquitetura:
  - `checkout.shipping.quote.requested`
  - `shipping.promise.calculated`
  - `order.created`
  - `shipment.created`
  - `shipment.status.updated`
- As integrações usam envelope Kafka com `eventId`, `eventType`, `schemaVersion`, `occurredAt`, `correlationId`, `producer` e `payload`.
- Os serviços usam `localhost:9092` para desenvolvimento local.
- `ShippingPromiseService` passou a consumir `checkout.shipping.quote.requested`.
- `shipping.promise.calculated` passou a carregar `checkoutId`.
- `order.created` foi enriquecido para atender o `ShipmentService`.
- `shipment.created` e `shipment.status.updated` passaram a propagar `orderId` e `buyerId`.
- O `OrderService` teve seus tópicos internos de saga formalizados por ADR.

## Bloqueios remanescentes

| Severidade | Bloqueio | Impacto | Status |
|---|---|---|---|
| Média | Executar `dotnet restore`, `dotnet build`, `dotnet test` em todos os microservices | Confirma compatibilidade de compilação/testes | Pendente de ambiente local/CI |
| Média | Aplicar schemas locais de Postgres quando serviços exigirem Outbox/Inbox reais | Necessário para E2E real com persistência | Pendente de ambiente local |
| Baixa | Validar execução Docker/Kafka completa | Confirma runbook em máquina local | Pendente de execução local |

## Comandos Docker/Kafka revisados

Os comandos do runbook foram revisados estaticamente:

```bash
docker compose up -d
docker compose ps
docker exec -it meli-envios-kafka kafka-topics --bootstrap-server localhost:9092 --create --if-not-exists --topic order.created --partitions 1 --replication-factor 1
docker exec -it meli-envios-kafka kafka-topics --bootstrap-server localhost:9092 --list
docker compose down -v
```

Observação: a revisão confirma consistência de comandos e nomes de containers/tópicos com o `docker-compose.yml`. A execução deve ser feita em ambiente local ou CI.

## Parecer final

As correções de contrato Kafka foram refletidas na documentação de arquitetura.

O próximo passo é executar a validação local por fases descrita no runbook:

1. subir infraestrutura;
2. criar tópicos;
3. executar smoke test por tópico;
4. executar promise assíncrona;
5. executar pedido/shipment/tracking/notification;
6. executar E2E integrado;
7. rodar build/test em todos os microservices.
