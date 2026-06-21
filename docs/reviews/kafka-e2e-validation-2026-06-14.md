# Validação Kafka E2E local - Microservices Logística Envios

Data: 2026-06-14

Última revisão documental: 2026-06-21

## Escopo

Validação estática dos contratos e runbooks necessários para habilitar teste end-to-end local com Kafka entre os microservices principais:

- `CheckoutService`
- `ShippingPromiseService`
- `OrderService`
- `ShipmentService`
- `TrackingService`
- `NotificationService`
- `AuditService`

Referências arquiteturais usadas:

- `docs/contracts/kafka-events.md`
- `docs/contracts/kafka-schema-governance.md`
- `docs/runbooks/kafka-local-e2e.md`
- `docs/adr/0007-order-service-internal-saga-topics.md`
- `docker-compose.yml`
- diagramas C4 em `docs/c4`

## Resultado executivo

Status geral: **pronto para validação E2E local por fases**.

Os contratos Kafka canônicos estão alinhados entre os serviços principais. O broker local está definido no `docker-compose.yml` como:

- Broker externo para serviços rodando na máquina: `localhost:9092`
- Broker interno para containers: `kafka:29092`
- Kafka UI: `http://localhost:8088`

A validação final ainda depende da execução local ou em CI dos microservices com .NET 8, Postgres, Redis e Kafka.

## Matriz de implementação esperada

| Serviço | Producer | Consumer | Consumer group | Status documental |
|---|---|---|---|---|
| `CheckoutService` | `checkout.shipping.quote.requested`, `checkout.confirmed` | `shipping.promise.calculated` | `checkout-service` | Alinhado |
| `ShippingPromiseService` | `shipping.promise.calculated` | `checkout.shipping.quote.requested` | `shipping-promise-service` | Alinhado |
| `OrderService` | `order.created`, `order.confirmed`, `order.cancelled` e tópicos internos de saga | `checkout.confirmed`, `shipment.status.updated`, `payment.approved`, `payment.rejected` | `order-service` | Alinhado |
| `ShipmentService` | `shipment.created`, `shipment.cancelled` | `order.created` | `shipment-service` | Alinhado |
| `TrackingService` | `shipment.status.updated` | `shipment.created`, `shipment.cancelled` | `tracking-service` | Alinhado |
| `NotificationService` | - | `order.created`, `order.confirmed`, `order.cancelled`, `shipment.created`, `shipment.status.updated`, `shipment.cancelled`, `payment.rejected` | `notification-service` | Alinhado |
| `AuditService` | - | Eventos canônicos de domínio | `audit-service` | Alinhado |

## Tópicos canônicos validados

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

## Tópicos internos de saga

O `OrderService` utiliza tópicos internos para orquestração da saga. Esses tópicos foram formalizados pela [`ADR-0007`](../adr/0007-order-service-internal-saga-topics.md) e documentados em `docs/contracts/kafka-events.md`.

| Tópico | Tipo | Producer | Consumer principal | Status |
|---|---|---|---|---|
| `inventory.commands` | Command | `order-service` | `inventory-service` | Interno documentado |
| `fulfillment.commands` | Command | `order-service` | `fulfillment-center-service` | Interno documentado |
| `payment.commands` | Command | `order-service` | `payment-service` | Interno documentado |
| `shipment.commands` | Command | `order-service` | `shipment-service` | Interno documentado |
| `order.events` | Internal Event | `order-service` | Consumidores internos controlados | Interno documentado |

## Ordem recomendada para execução local

### Fase 0 - Infraestrutura Kafka

1. Subir Kafka, Kafka UI, Redis e Postgres.
2. Criar tópicos canônicos.
3. Criar tópicos internos de saga.
4. Validar tópicos no Kafka UI.

### Fase 1 - Smoke test por tópico

Validar produção e consumo manual dos tópicos principais:

```text
checkout.shipping.quote.requested
shipping.promise.calculated
checkout.confirmed
order.created
shipment.created
shipment.status.updated
```

### Fase 2 - Promise assíncrona

Serviços mínimos:

```text
CheckoutService
ShippingPromiseService
```

Fluxo esperado:

1. `CheckoutService` publica `checkout.shipping.quote.requested` com `checkoutId`.
2. `ShippingPromiseService` consome `checkout.shipping.quote.requested`.
3. `ShippingPromiseService` publica `shipping.promise.calculated` com o mesmo `checkoutId`.
4. `CheckoutService` consome `shipping.promise.calculated` e grava/projeta a promise.

### Fase 3 - Confirmação de checkout e criação de pedido

Serviços mínimos:

```text
CheckoutService
OrderService
```

Fluxo esperado:

1. `CheckoutService` confirma o checkout.
2. `CheckoutService` publica `checkout.confirmed`.
3. `OrderService` consome `checkout.confirmed`.
4. `OrderService` inicia a saga de criação de pedido.
5. `OrderService` publica `order.created` após conclusão da criação do pedido.

### Fase 4 - Pedido, shipment, tracking e notification

Serviços mínimos:

```text
OrderService
ShipmentService
TrackingService
NotificationService
```

Fluxo esperado:

1. `OrderService` publica `order.created`.
2. `ShipmentService` consome `order.created` e publica `shipment.created`.
3. `TrackingService` consome `shipment.created` e publica `shipment.status.updated`.
4. `NotificationService` consome eventos canônicos relevantes.
5. `OrderService` consome `shipment.status.updated` e atualiza status de entrega no pedido.

### Fase 5 - E2E integrado

Serviços:

```text
CheckoutService
ShippingPromiseService
OrderService
ShipmentService
TrackingService
NotificationService
AuditService
```

Objetivo:

1. Criar checkout.
2. Calcular promise assíncrona.
3. Confirmar checkout.
4. Criar pedido.
5. Criar shipment.
6. Atualizar tracking/status inicial.
7. Planejar notificações.
8. Persistir trilha de auditoria.
9. Validar mensagens no Kafka UI.

## Comandos de validação local

Criar tópicos canônicos manualmente, se necessário:

```bash
docker exec -it logistica-envios-kafka kafka-topics --bootstrap-server localhost:9092 --create --if-not-exists --topic checkout.shipping.quote.requested --partitions 1 --replication-factor 1

docker exec -it logistica-envios-kafka kafka-topics --bootstrap-server localhost:9092 --create --if-not-exists --topic shipping.promise.calculated --partitions 1 --replication-factor 1

docker exec -it logistica-envios-kafka kafka-topics --bootstrap-server localhost:9092 --create --if-not-exists --topic checkout.confirmed --partitions 1 --replication-factor 1

docker exec -it logistica-envios-kafka kafka-topics --bootstrap-server localhost:9092 --create --if-not-exists --topic order.created --partitions 1 --replication-factor 1

docker exec -it logistica-envios-kafka kafka-topics --bootstrap-server localhost:9092 --create --if-not-exists --topic shipment.created --partitions 1 --replication-factor 1

docker exec -it logistica-envios-kafka kafka-topics --bootstrap-server localhost:9092 --create --if-not-exists --topic shipment.status.updated --partitions 1 --replication-factor 1
```

Listar tópicos:

```bash
docker exec -it logistica-envios-kafka kafka-topics --bootstrap-server localhost:9092 --list
```

Abrir UI:

```text
http://localhost:8088
```

## Bloqueios e riscos operacionais

1. Alguns serviços podem exigir `DbContext`, `Inbox` e `Outbox` reais mesmo com repository mock habilitado.
2. Para E2E real, é necessário aplicar schemas locais ou usar mocks transacionais para Inbox/Outbox quando implementados.
3. Health checks podem falhar em modo mock se ainda dependerem de banco real.
4. A execução final deve rodar `dotnet restore`, `dotnet build`, `dotnet test` e o fluxo Kafka local/CI nos repositórios de microservice.

## Parecer final

A arquitetura documental está coerente para validação E2E local por fases. Os tópicos canônicos, os tópicos internos de saga, o runbook Kafka e as specs de serviço estão alinhados. A principal pendência restante é operacional: executar o E2E real em ambiente local ou CI com os microservices e schemas necessários.
