# Runbook - Kafka local E2E

## Objetivo

Executar e validar localmente a comunicação Kafka entre os microservices do case Logística Envios.

## Status atual

Status: **implementação de consumers e outbox concluída — pronto para validação E2E local por fases**.

### O que está implementado neste monorepo

| Serviço | Consumer Kafka | OutboxDispatcher | schema.sql |
|---|---|---|---|
| `CheckoutService` | `ShippingPromiseCalculatedConsumer` | `OutboxKafkaDispatcher` | Adicionado |
| `ShippingPromiseService` | consumer existente | dispatcher existente | Existente |
| `OrderService` | `CheckoutConfirmedConsumer`, `InventoryReservedConsumer`, `InventoryReservationFailedConsumer`, `FulfillmentCapacityReservedConsumer`, `FulfillmentCapacityFailedConsumer`, `ShipmentCreatedConsumer`, `ShipmentStatusUpdatedConsumer` | `OutboxDispatcher` | Existente |
| `InventoryService` | `InventoryCommandsConsumer` | `OutboxDispatcher` | Existente |
| `FulfillmentCenterService` | `FulfillmentCommandsConsumer` | `OutboxDispatcher` | Adicionado |
| `ShipmentService` | `OrderCreatedKafkaConsumer`, `ShipmentCommandsConsumer` | `OutboxDispatcher` | Existente |
| `TrackingService` | consumer existente | dispatcher existente | Adicionado |
| `NotificationService` | `KafkaNotificationConsumer` | `OutboxDispatcher` | Adicionado |

### O que NÃO está disponível localmente

| Serviço ausente | Impacto | Solução para E2E local |
|---|---|---|
| `PaymentService` | Saga fica bloqueada aguardando `payment.authorized` | Simular manualmente via Kafka UI (ver Fase 3) |
| `AuditService` | Sem auditoria de eventos | Ignorar para E2E funcional |

A validação final depende de execução local com .NET 8, Docker, Postgres, Redis e Kafka.

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

## Pré-requisitos: aplicar schemas SQL

Após subir o Postgres (`docker compose up -d`), aplique os schemas de cada serviço.

O banco é `logistica_envios`, usuário `logistica`, senha `logistica`, porta `5432`.

```bash
# Variável de conexão (reutilize nos comandos abaixo)
PGCONN="postgresql://logistica:logistica@localhost:5432/logistica_envios"

# Aplicar schemas
psql "$PGCONN" -f CheckoutService/Infrastructure/Persistence/schema.sql
psql "$PGCONN" -f ShippingPromiseService/Infrastructure/Persistence/schema.sql
psql "$PGCONN" -f OrderService/Infrastructure/Persistence/schema.sql
psql "$PGCONN" -f InventoryService/Infrastructure/Persistence/schema.sql
psql "$PGCONN" -f FulfillmentCenterService/Infrastructure/Persistence/schema.sql
psql "$PGCONN" -f ShipmentService/Infrastructure/Persistence/schema.sql
psql "$PGCONN" -f TrackingService/Infrastructure/Persistence/schema.sql
psql "$PGCONN" -f NotificationService/Infrastructure/Persistence/schema.sql
```

> **Nota**: Os schemas são idempotentes somente na primeira execução. Se precisar re-aplicar, rode `DROP TABLE ... CASCADE` nas tabelas ou recrie o banco com `docker compose down -v && docker compose up -d`.

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

docker exec -it logistica-envios-kafka kafka-topics --bootstrap-server localhost:9092 --create --if-not-exists --topic order.confirmed --partitions 1 --replication-factor 1

docker exec -it logistica-envios-kafka kafka-topics --bootstrap-server localhost:9092 --create --if-not-exists --topic order.cancelled --partitions 1 --replication-factor 1

docker exec -it logistica-envios-kafka kafka-topics --bootstrap-server localhost:9092 --create --if-not-exists --topic payment.approved --partitions 1 --replication-factor 1

docker exec -it logistica-envios-kafka kafka-topics --bootstrap-server localhost:9092 --create --if-not-exists --topic payment.rejected --partitions 1 --replication-factor 1

docker exec -it logistica-envios-kafka kafka-topics --bootstrap-server localhost:9092 --create --if-not-exists --topic shipment.created --partitions 1 --replication-factor 1

docker exec -it logistica-envios-kafka kafka-topics --bootstrap-server localhost:9092 --create --if-not-exists --topic shipment.status.updated --partitions 1 --replication-factor 1

docker exec -it logistica-envios-kafka kafka-topics --bootstrap-server localhost:9092 --create --if-not-exists --topic shipment.cancelled --partitions 1 --replication-factor 1
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

### Tópicos de resposta da saga (inventory/fulfillment)

Esses tópicos são usados pelo `InventoryService` e `FulfillmentCenterService` para responder ao `OrderService` via outbox.

```bash
docker exec -it logistica-envios-kafka kafka-topics --bootstrap-server localhost:9092 --create --if-not-exists --topic inventory.reserved --partitions 1 --replication-factor 1

docker exec -it logistica-envios-kafka kafka-topics --bootstrap-server localhost:9092 --create --if-not-exists --topic inventory.reservation.confirmed --partitions 1 --replication-factor 1

docker exec -it logistica-envios-kafka kafka-topics --bootstrap-server localhost:9092 --create --if-not-exists --topic inventory.reservation.failed --partitions 1 --replication-factor 1

docker exec -it logistica-envios-kafka kafka-topics --bootstrap-server localhost:9092 --create --if-not-exists --topic inventory.reservation.released --partitions 1 --replication-factor 1

docker exec -it logistica-envios-kafka kafka-topics --bootstrap-server localhost:9092 --create --if-not-exists --topic fulfillment.capacity.reserved --partitions 1 --replication-factor 1

docker exec -it logistica-envios-kafka kafka-topics --bootstrap-server localhost:9092 --create --if-not-exists --topic fulfillment.capacity.confirmed --partitions 1 --replication-factor 1

docker exec -it logistica-envios-kafka kafka-topics --bootstrap-server localhost:9092 --create --if-not-exists --topic fulfillment.capacity.failed --partitions 1 --replication-factor 1
```

Listar tópicos:

```bash
docker exec -it logistica-envios-kafka kafka-topics --bootstrap-server localhost:9092 --list
```

## Microservices com Kafka implementado

| Serviço | Producer (via outbox) | Consumer(s) implementado(s) | Consumer group | Status |
|---|---|---|---|---|
| `CheckoutService` | `checkout.shipping.quote.requested`, `checkout.confirmed` | `ShippingPromiseCalculatedConsumer` | `checkout-service` | **Implementado** |
| `ShippingPromiseService` | `shipping.promise.calculated` | consumer de `checkout.shipping.quote.requested` | `shipping-promise-service` | **Implementado** |
| `OrderService` | `order.created`, tópicos internos de saga | `CheckoutConfirmedConsumer`, `InventoryReservedConsumer`, `InventoryReservationFailedConsumer`, `FulfillmentCapacityReservedConsumer`, `FulfillmentCapacityFailedConsumer`, `ShipmentCreatedConsumer`, `ShipmentStatusUpdatedConsumer` | `order-service` | **Implementado** |
| `InventoryService` | `inventory.reserved`, `inventory.reservation.confirmed`, `inventory.reservation.failed`, `inventory.reservation.released` | `InventoryCommandsConsumer` | `inventory-service` | **Implementado** |
| `FulfillmentCenterService` | `fulfillment.capacity.reserved`, `fulfillment.capacity.confirmed`, `fulfillment.capacity.failed` | `FulfillmentCommandsConsumer` | `fulfillment-center-service` | **Implementado** |
| `ShipmentService` | `shipment.created` | `OrderCreatedKafkaConsumer`, `ShipmentCommandsConsumer` | `shipment-service` | **Implementado** |
| `TrackingService` | `shipment.status.updated` | consumer de `shipment.created` | `tracking-service` | **Implementado** |
| `NotificationService` | — | `KafkaNotificationConsumer` (múltiplos tópicos) | `notification-service` | **Implementado** |
| `PaymentService` | `payment.approved`, `payment.rejected` | `payment.commands` | `payment-service` | **Ausente** — simular manualmente |
| `AuditService` | — | Todos os eventos canônicos | `audit-service` | **Ausente** — ignorar para E2E local |

## Matriz final de tópicos canônicos

| Tópico | Producer | Consumers | Status |
|---|---|---|---|
| `checkout.shipping.quote.requested` | `checkout-service` | `shipping-promise-service`, `audit-service`, `analytics` | Alinhado |
| `shipping.promise.calculated` | `shipping-promise-service` | `checkout-service`, `audit-service`, `analytics` | Alinhado |
| `checkout.confirmed` | `checkout-service` | `order-service`, `audit-service` | Alinhado |
| `order.created` | `order-service` | `shipment-service`, `notification-service`, `audit-service` | Alinhado |
| `order.confirmed` | `order-service` | `notification-service`, `audit-service` | Especificado |
| `order.cancelled` | `order-service` | `shipment-service`, `notification-service`, `audit-service`, `inventory-service` | Especificado |
| `payment.approved` | `payment-service` | `order-service`, `audit-service` | Especificado |
| `payment.rejected` | `payment-service` | `order-service`, `notification-service`, `audit-service` | Especificado |
| `shipment.created` | `shipment-service` | `tracking-service`, `notification-service`, `audit-service` | Alinhado |
| `shipment.status.updated` | `tracking-service` | `notification-service`, `audit-service`, `order-service` | Alinhado |
| `shipment.cancelled` | `shipment-service` | `tracking-service`, `notification-service`, `order-service`, `audit-service` | Especificado |

## Matriz de tópicos internos de saga

| Tópico | Producer | Consumer principal | Finalidade |
|---|---|---|---|
| `inventory.commands` | `order-service` | `inventory-service` | Reservar, confirmar ou liberar estoque |
| `inventory.reserved` | `inventory-service` | `order-service` | Confirma reserva de estoque bem-sucedida |
| `inventory.reservation.confirmed` | `inventory-service` | `order-service` | Confirma que reserva foi efetivada após pagamento autorizado |
| `inventory.reservation.failed` | `inventory-service` | `order-service` | Falha na reserva — dispara compensação na saga |
| `inventory.reservation.released` | `inventory-service` | `order-service` | Estoque liberado após compensação |
| `fulfillment.commands` | `order-service` | `fulfillment-center-service` | Validar capacidade e acionar preparação logística |
| `fulfillment.capacity.reserved` | `fulfillment-center-service` | `order-service` | Confirma reserva de capacidade bem-sucedida |
| `fulfillment.capacity.confirmed` | `fulfillment-center-service` | `order-service` | Capacidade efetivada após pagamento autorizado |
| `fulfillment.capacity.failed` | `fulfillment-center-service` | `order-service` | Falha na reserva de capacidade — dispara compensação |
| `payment.commands` | `order-service` | `payment-service` | Autorizar, capturar, cancelar ou estornar pagamento |
| `shipment.commands` | `order-service` | `shipment-service` | Criar, cancelar ou atualizar entrega |
| `order.events` | `order-service` | consumidores internos controlados | Publicar mudanças internas do ciclo de vida do pedido |

## Ordem recomendada para teste por fases

### Fase 0 - Infraestrutura Kafka

1. Subir Kafka, Kafka UI, Redis e Postgres.
2. Criar os 11 tópicos canônicos.
3. Criar os 5 tópicos internos de saga.
4. Validar tópicos no Kafka UI.

### Fase 1 - Smoke test por tópico

Antes do E2E entre serviços, validar produção/consumo manual dos tópicos canônicos e internos com `kafka-console-producer` e `kafka-console-consumer`.

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
AuditService
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
5. `AuditService` audita os eventos canônicos.

### Fase 3 - Confirmação de checkout, pedido e pagamento (sem PaymentService)

> `PaymentService` não está disponível neste monorepo. O `payment.commands` será publicado pelo `OrderService` mas não terá consumidor. Simule `payment.authorized` manualmente conforme instruções abaixo.

Rodar serviços:

```text
CheckoutService
OrderService
InventoryService
FulfillmentCenterService
```

Tópicos usados:

```text
checkout.confirmed
inventory.commands
inventory.reserved
inventory.reservation.confirmed
inventory.reservation.failed
fulfillment.commands
fulfillment.capacity.reserved
fulfillment.capacity.confirmed
fulfillment.capacity.failed
payment.commands
order.created
```

Objetivo esperado:

1. `CheckoutService` confirma o checkout e publica `checkout.confirmed`.
2. `OrderService` consome `checkout.confirmed`, cria o pedido e publica:
   - `order.created` (para `ShipmentService`)
   - `inventory.commands` (para `InventoryService`)
   - `fulfillment.commands` (para `FulfillmentCenterService`)
3. `InventoryService` reserva estoque e publica `inventory.reserved`.
4. `FulfillmentCenterService` reserva capacidade e publica `fulfillment.capacity.reserved`.
5. `OrderService` recebe ambas as reservas e publica `payment.commands` (sem consumidor).

#### Simulação manual de payment.authorized

Após o `OrderService` publicar `payment.commands`, simule o `PaymentService` publicando `payment.authorized` manualmente:

Via `kafka-console-producer`:

```bash
docker exec -it logistica-envios-kafka kafka-console-producer \
  --bootstrap-server localhost:9092 \
  --topic payment.approved
```

Cole o JSON abaixo (substitua `<ORDER_ID>` pelo ID real do pedido — veja no log do `OrderService` ou no Kafka UI no tópico `payment.commands`):

```json
{"eventId":"00000000-0000-0000-0000-000000000001","eventType":"payment.approved","schemaVersion":"1.0","occurredAt":"2026-06-22T00:00:00Z","correlationId":"manual-sim","producer":"payment-service-manual","payload":{"messageId":"00000000-0000-0000-0000-000000000002","orderId":"<ORDER_ID>","paymentAuthorizationId":"00000000-0000-0000-0000-000000000003"}}
```

Via Kafka UI (`http://localhost:8088`):

1. Acesse o cluster → Topics → `payment.approved`.
2. Clique em **Produce Message**.
3. Cole o JSON acima no campo **Value** com o `ORDER_ID` correto.
4. Clique em **Produce**.

Após a simulação:

6. `OrderService` recebe `payment.approved` e publica `inventory.commands` (confirmar) + `fulfillment.commands` (confirmar).
7. Ambos os serviços confirmam e publicam `inventory.reservation.confirmed` e `fulfillment.capacity.confirmed`.
8. `OrderService` recebe ambas as confirmações e publica `shipment.commands`.

### Fase 4 - Shipment, tracking e notification

Rodar serviços:

```text
OrderService
ShipmentService
TrackingService
NotificationService
AuditService
```

Tópicos usados:

```text
order.created
order.confirmed
order.cancelled
shipment.commands
shipment.created
shipment.status.updated
shipment.cancelled
```

Objetivo esperado:

1. `ShipmentService` consome `order.created` ou `shipment.commands` e publica `shipment.created`.
2. `TrackingService` consome `shipment.created` e publica `shipment.status.updated`.
3. `NotificationService` consome eventos de pedido, pagamento e shipment.
4. `OrderService` consome `shipment.status.updated` e atualiza status de entrega.
5. `AuditService` audita todos os eventos canônicos.

### Fase 5 - E2E integrado

Rodar serviços:

```text
CheckoutService
ShippingPromiseService
OrderService
InventoryService
FulfillmentCenterService
PaymentService
ShipmentService
TrackingService
NotificationService
AuditService
```

Objetivo:

1. Criar checkout.
2. Calcular promise assíncrona.
3. Confirmar checkout.
4. Executar saga com estoque, fulfillment e pagamento.
5. Criar pedido.
6. Criar shipment.
7. Criar tracking/status inicial.
8. Planejar notificações.
9. Auditar eventos.
10. Validar mensagens no Kafka UI.

## Configuração esperada em appsettings.Development.json

Exemplo base:

```json
{
  "Kafka": {
    "BootstrapServers": "localhost:9092",
    "ConsumerGroupId": "nome-do-servico",
    "Topics": {}
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
   - `payment-service`
   - `shipment-service`
   - `tracking-service`
   - `notification-service`
   - `audit-service`

## Resetar ambiente

```bash
docker compose down -v
docker compose up -d
```
