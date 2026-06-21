# Runbook - Kafka local E2E

## Objetivo

Executar e validar localmente a comunicação Kafka entre os microservices do case Logística Envios.

## Status atual

Status: **pronto para validação E2E local por fases**.

Os contratos Kafka canônicos foram alinhados entre os microservices avaliados. A validação final ainda depende de execução local/CI com .NET 8, Docker, Postgres, Redis e Kafka.

Revisão relacionada: [`docs/reviews/kafka-e2e-contract-review-2026-06-14.md`](../reviews/kafka-e2e-contract-review-2026-06-14.md).

Contrato canônico: [`docs/contracts/kafka-events.md`](../contracts/kafka-events.md).

## Endpoints locais

| Recurso | Endereço |
|---|---|
| Kafka UI | `http://localhost:8088` |
| Kafka broker para apps locais | `localhost:9092` |
| Kafka broker para containers no compose | `kafka:29092` |
| Redis local | `localhost:6379` |
| Postgres local | `localhost:5432` |

Importante: `http://localhost:8088` é apenas a interface web do Kafka UI. Microservices não devem apontar para `8088`; devem usar `localhost:9092` quando rodando fora do Docker.

## Subir infraestrutura

No repo `logistica-envios-demo-arch`:

```bash
docker compose up -d
```

Validar containers:

```bash
docker compose ps
```

Abrir Kafka UI:

```text
http://localhost:8088
```

## Criar tópicos canônicos

Os comandos usam `--if-not-exists` para permitir reexecução segura.

```bash
docker exec -it logistica-envios-kafka kafka-topics --bootstrap-server localhost:9092 --create --if-not-exists --topic checkout.shipping.quote.requested --partitions 1 --replication-factor 1

docker exec -it logistica-envios-kafka kafka-topics --bootstrap-server localhost:9092 --create --if-not-exists --topic shipping.promise.calculated --partitions 1 --replication-factor 1

docker exec -it logistica-envios-kafka kafka-topics --bootstrap-server localhost:9092 --create --if-not-exists --topic checkout.confirmed --partitions 1 --replication-factor 1

docker exec -it logistica-envios-kafka kafka-topics --bootstrap-server localhost:9092 --create --if-not-exists --topic order.created --partitions 1 --replication-factor 1

docker exec -it logistica-envios-kafka kafka-topics --bootstrap-server localhost:9092 --create --if-not-exists --topic shipment.created --partitions 1 --replication-factor 1

docker exec -it logistica-envios-kafka kafka-topics --bootstrap-server localhost:9092 --create --if-not-exists --topic shipment.status.updated --partitions 1 --replication-factor 1
```

## Criar tópicos internos de saga do OrderService

Esses tópicos foram formalizados pela [`ADR-0007`](../adr/0007-order-service-internal-saga-topics.md).

```bash
docker exec -it logistica-envios-kafka kafka-topics --bootstrap-server localhost:9092 --create --if-not-exists --topic inventory.commands --partitions 1 --replication-factor 1

docker exec -it logistica-envios-kafka kafka-topics --bootstrap-server localhost:9092 --create --if-not-exists --topic fulfillment.commands --partitions 1 --replication-factor 1

docker exec -it logistica-envios-kafka kafka-topics --bootstrap-server localhost:9092 --create --if-not-exists --topic payment.commands --partitions 1 --replication-factor 1

docker exec -it logistica-envios-kafka kafka-topics --bootstrap-server localhost:9092 --create --if-not-exists --topic shipment.commands --partitions 1 --replication-factor 1

docker exec -it logistica-envios-kafka kafka-topics --bootstrap-server localhost:9092 --create --if-not-exists --topic order.events --partitions 1 --replication-factor 1
```

Listar tópicos:

```bash
docker exec -it logistica-envios-kafka kafka-topics --bootstrap-server localhost:9092 --list
```

## Microservices com Kafka implementado

| Serviço | Producer | Consumer | Consumer group | Status |
|---|---|---|---|---|
| `CheckoutService` | `checkout.shipping.quote.requested`, `checkout.confirmed` | `shipping.promise.calculated` | `checkout-service` | Alinhado |
| `ShippingPromiseService` | `shipping.promise.calculated` | `checkout.shipping.quote.requested` | `shipping-promise-service` | Alinhado |
| `OrderService` | `order.created` e tópicos internos de saga | `checkout.confirmed`, `shipment.status.updated` | `order-service` | Alinhado |
| `ShipmentService` | `shipment.created` | `order.created` | `shipment-service` | Alinhado |
| `TrackingService` | `shipment.status.updated` | `shipment.created` | `tracking-service` | Alinhado |
| `NotificationService` | - | `order.created`, `shipment.created`, `shipment.status.updated` | `notification-service` | Alinhado |

## Matriz final de tópicos

| Tópico | Producer | Consumers | Payload obrigatório | Status |
|---|---|---|---|---|
| `checkout.shipping.quote.requested` | `checkout-service` | `shipping-promise-service` | `checkoutId`, `buyerId`, `sellerId`, `destination`, `items[]` | Alinhado |
| `shipping.promise.calculated` | `shipping-promise-service` | `checkout-service` | `checkoutId`, `buyerId`, `sellerId`, `promiseId`, `mode`, `carrier`, `estimatedDeliveryDate`, `cost`, `currency`, `source` | Alinhado |
| `checkout.confirmed` | `checkout-service` | `order-service`, `audit-service` | `checkoutId`, `buyerId`, `sellerId`, `shippingPromiseId`, `items[]`, `totalAmount`, `currency`, `confirmedAt` | Alinhado |
| `order.created` | `order-service` | `shipment-service`, `notification-service` | `orderId`, `checkoutId`, `buyerId`, `sellerId`, `shippingPromiseId`, `routeId`, `carrierCode`, `serviceLevelCode`, `originNodeId`, `promisedDeliveryDate`, `destination`, `packages[]`, `totalAmount`, `currency`, `createdAt` | Alinhado |
| `shipment.created` | `shipment-service` | `tracking-service`, `notification-service` | `shipmentId`, `orderId`, `buyerId`, `sellerId`, `carrierCode`, `serviceLevelCode`, `externalShipmentId`, `trackingCode`, `labelObjectKey`, `estimatedDeliveryDate`, `createdAt` | Alinhado |
| `shipment.status.updated` | `tracking-service` | `order-service`, `notification-service` | `shipmentId`, `orderId`, `buyerId`, `trackingCode`, `carrierCode`, `previousStatus`, `currentStatus`, `statusDate`, `estimatedDeliveryDate`, `exceptionCode` | Alinhado |

## Ordem recomendada para teste por fases

### Fase 0 - Infraestrutura Kafka

Objetivo:

1. Subir Kafka, Kafka UI, Redis e Postgres.
2. Criar tópicos canônicos.
3. Criar tópicos internos de saga.
4. Validar tópicos no Kafka UI.

### Fase 1 - Smoke test por tópico

Antes do E2E entre serviços, validar produção/consumo manual dos tópicos:

```text
checkout.shipping.quote.requested
shipping.promise.calculated
checkout.confirmed
order.created
shipment.created
shipment.status.updated
```

Use `kafka-console-producer` e `kafka-console-consumer` para validar conectividade básica.

Exemplo de consumo:

```bash
docker exec -it logistica-envios-kafka kafka-console-consumer --bootstrap-server localhost:9092 --topic order.created --from-beginning
```

Exemplo de produção manual:

```bash
docker exec -it logistica-envios-kafka kafka-console-producer --bootstrap-server localhost:9092 --topic order.created
```

### Fase 2 - Promise assíncrona

Rodar serviços:

```text
CheckoutService
ShippingPromiseService
```

Tópicos:

```text
checkout.shipping.quote.requested
shipping.promise.calculated
```

Objetivo esperado:

1. `CheckoutService` publica `checkout.shipping.quote.requested` com `checkoutId`.
2. `ShippingPromiseService` consome `checkout.shipping.quote.requested`.
3. `ShippingPromiseService` publica `shipping.promise.calculated` com o mesmo `checkoutId`.
4. `CheckoutService` consome `shipping.promise.calculated` e grava/projeta a promise.

### Fase 3 - Confirmação de checkout e criação de pedido

Rodar serviços:

```text
CheckoutService
OrderService
```

Tópicos usados:

```text
checkout.confirmed
order.created
```

Objetivo esperado:

1. `CheckoutService` confirma o checkout e publica `checkout.confirmed`.
2. `OrderService` consome `checkout.confirmed` e inicia a saga do pedido.
3. `OrderService` publica `order.created` com dados logísticos suficientes para criação da entrega.

### Fase 4 - Pedido, shipment, tracking e notification

Rodar serviços:

```text
OrderService
ShipmentService
TrackingService
NotificationService
```

Tópicos usados:

```text
order.created
shipment.created
shipment.status.updated
```

Objetivo esperado:

1. `OrderService` publica `order.created` com dados logísticos suficientes para criação da entrega.
2. `ShipmentService` consome `order.created` e publica `shipment.created` com `orderId` e `buyerId`.
3. `TrackingService` consome `shipment.created` e publica `shipment.status.updated` com `orderId` e `buyerId`.
4. `NotificationService` consome `order.created`, `shipment.created` e `shipment.status.updated`.
5. `OrderService` consome `shipment.status.updated` e atualiza status de entrega no pedido.

### Fase 5 - E2E integrado

Rodar serviços:

```text
CheckoutService
ShippingPromiseService
OrderService
ShipmentService
TrackingService
NotificationService
```

Objetivo:

1. Criar checkout.
2. Calcular promise assíncrona.
3. Confirmar checkout.
4. Criar pedido.
5. Criar shipment.
6. Criar tracking/status inicial.
7. Planejar notificações.
8. Validar mensagens no Kafka UI.

## Configuração esperada em appsettings.Development.json

Exemplo base:

```json
{
  "Kafka": {
    "BootstrapServers": "localhost:9092",
    "ConsumerGroupId": "nome-do-servico",
    "Topics": {
    }
  }
}
```

## Pré-validações por microservice

Execute em cada repo de microservice:

```bash
dotnet restore
dotnet build
dotnet test
```

## Pontos de atenção

1. Alguns serviços ainda podem exigir `DbContext`, `Inbox` e `Outbox` reais mesmo com repository mock habilitado.
2. Para E2E real, aplique os schemas locais ou use mocks transacionais para Inbox/Outbox quando implementados.
3. O `OrderService` possui tópicos internos de saga documentados pela ADR-0007.
4. Os comandos Docker/Kafka deste runbook foram revisados estaticamente; a execução final deve ser feita localmente ou em CI.

## Validação visual

No Kafka UI:

1. Acesse `http://localhost:8088`.
2. Abra o cluster `local`.
3. Verifique os tópicos.
4. Acompanhe mensagens nos tópicos canônicos.
5. Confira consumer groups:
   - `checkout-service`
   - `shipping-promise-service`
   - `order-service`
   - `shipment-service`
   - `tracking-service`
   - `notification-service`

## Resetar ambiente

```bash
docker compose down -v
docker compose up -d
```
