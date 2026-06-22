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

Listar tópicos:

```bash
docker exec -it logistica-envios-kafka kafka-topics --bootstrap-server localhost:9092 --list
```

## Microservices com Kafka implementado ou previsto

| Serviço | Producer | Consumer | Consumer group | Status |
|---|---|---|---|---|
| `CheckoutService` | `checkout.shipping.quote.requested`, `checkout.confirmed` | `shipping.promise.calculated` | `checkout-service` | Alinhado |
| `ShippingPromiseService` | `shipping.promise.calculated` | `checkout.shipping.quote.requested` | `shipping-promise-service` | Alinhado |
| `OrderService` | `order.created`, `order.confirmed`, `order.cancelled`, tópicos internos de saga | `checkout.confirmed`, `shipment.status.updated`, `payment.approved`, `payment.rejected` | `order-service` | Alinhado |
| `PaymentService` | `payment.approved`, `payment.rejected` | `payment.commands` | `payment-service` | Alinhado |
| `InventoryService` | - | `inventory.commands` | `inventory-service` | Saga interna |
| `FulfillmentCenterService` | - | `fulfillment.commands` | `fulfillment-center-service` | Saga interna |
| `ShipmentService` | `shipment.created`, `shipment.cancelled` | `order.created`, `order.cancelled`, `shipment.commands` | `shipment-service` | Alinhado |
| `TrackingService` | `shipment.status.updated` | `shipment.created` | `tracking-service` | Alinhado |
| `NotificationService` | - | `order.created`, `order.confirmed`, `order.cancelled`, `payment.rejected`, `shipment.created`, `shipment.status.updated`, `shipment.cancelled` | `notification-service` | Alinhado |
| `AuditService` | - | Todos os eventos canônicos auditáveis | `audit-service` | Alinhado |

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
| `fulfillment.commands` | `order-service` | `fulfillment-center-service` | Validar capacidade e acionar preparação logística |
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

### Fase 3 - Confirmação de checkout, pedido e pagamento

Rodar serviços:

```text
CheckoutService
OrderService
InventoryService
FulfillmentCenterService
PaymentService
AuditService
```

Tópicos usados:

```text
checkout.confirmed
inventory.commands
fulfillment.commands
payment.commands
payment.approved
payment.rejected
order.created
order.confirmed
order.cancelled
```

Objetivo esperado:

1. `CheckoutService` confirma o checkout e publica `checkout.confirmed`.
2. `OrderService` consome `checkout.confirmed` e inicia a saga.
3. `OrderService` publica comandos internos de estoque, fulfillment e pagamento.
4. `PaymentService` publica `payment.approved` ou `payment.rejected`.
5. `OrderService` publica `order.created` e `order.confirmed` em sucesso, ou `order.cancelled` em falha/compensação.
6. `AuditService` audita os eventos canônicos.

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
