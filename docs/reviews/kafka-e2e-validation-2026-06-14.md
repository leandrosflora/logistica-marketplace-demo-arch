# Validação Kafka E2E local - Microservices Logística Envios

Data: 2026-06-14

## Escopo

Validação estática das modificações recentes nos microservices solicitados para habilitar teste end-to-end local com Kafka:

- `OrderService`
- `ShipmentService`
- `NotificationService`
- `CheckoutService`
- `ShippingPromiseService`
- `TrackingService`

Referência arquitetural usada:

- `docs/contracts/kafka-events.md`
- `docker-compose.yml`
- diagramas C4 N3 de Kafka em `docs/c4`

## Resultado executivo

Status geral: **parcialmente pronto para E2E Kafka local**.

O broker local está definido no `docker-compose.yml` como:

- Broker externo para serviços rodando na máquina: `localhost:9092`
- Broker interno para containers: `kafka:29092`
- Kafka UI: `http://localhost:8088`

Foram implementadas integrações Kafka reais em cinco serviços:

- `OrderService`
- `ShipmentService`
- `NotificationService`
- `ShippingPromiseService`
- `TrackingService`

O `CheckoutService` ainda não possui implementação Kafka detectável no código atual.

## Matriz de implementação validada

| Serviço | Kafka atual | Producer | Consumer | Status |
|---|---|---|---|---|
| `OrderService` | Real com `Confluent.Kafka` | `order.created` | `shipment.status.updated` | OK com ressalva |
| `ShipmentService` | Real com `Confluent.Kafka` | `shipment.created` via Outbox | `order.created` | OK com ressalva crítica |
| `TrackingService` | Real com `Confluent.Kafka` | `shipment.status.updated` via Outbox | `shipment.created` | OK com ressalva |
| `NotificationService` | Real consumer com `Confluent.Kafka` | Não publica | `order.created`, `shipment.created`, `shipment.status.updated` | OK com ressalva |
| `ShippingPromiseService` | Real producer com `Confluent.Kafka` | `shipping.promise.calculated` | Não consome | OK |
| `CheckoutService` | Não detectado | Pendente | Pendente | Não pronto para Kafka E2E completo |

## Tópicos canônicos usados

| Tópico | Producer | Consumers |
|---|---|---|
| `checkout.shipping.quote.requested` | `CheckoutService` | `audit-service`, `analytics` |
| `shipping.promise.calculated` | `ShippingPromiseService` | `CheckoutService`, `audit-service`, `analytics` |
| `order.created` | `OrderService` | `ShipmentService`, `NotificationService`, `AuditService` |
| `shipment.created` | `ShipmentService` | `TrackingService`, `NotificationService`, `AuditService` |
| `shipment.status.updated` | `TrackingService` | `NotificationService`, `AuditService`, `OrderService` |

## Evidências por serviço

### OrderService

PR validado:

- `OrderService#3` - `Add real Kafka integration (produce order.created, consume shipment.status.updated)`

Implementação observada:

- Configuração `Kafka:BootstrapServers = localhost:9092` em `appsettings.Development.json`.
- `ConsumerGroupId = order-service`.
- Tópicos configurados: `order.created` e `shipment.status.updated`.
- DI registra `IProducer<string,string>`, `KafkaIntegrationEventBus`, `OutboxDispatcher` e `ShipmentStatusUpdatedConsumer`.
- Consumer `ShipmentStatusUpdatedConsumer` assina `shipment.status.updated` e chama `OrderProcessManager.HandleShipmentStatusUpdatedAsync`.

Ressalva:

- O `OrderProcessManager` ainda grava comandos/tópicos legados fora do contrato canônico atual: `inventory.commands`, `fulfillment.commands`, `payment.commands`, `shipment.commands`, `order.events`.
- Esses tópicos devem ser classificados como tópicos internos de saga ou migrados para nomes canônicos em `docs/contracts/kafka-events.md`.

### ShipmentService

PR validado:

- `ShipmentService#5` - `Implement Kafka shipment creation flow`

Implementação observada:

- Configuração `Kafka:BootstrapServers = localhost:9092` em `appsettings.Development.json`.
- `ConsumerGroupId = shipment-service`.
- Tópicos configurados: `order.created` e `shipment.created`.
- `OrderCreatedKafkaConsumer` consome `order.created`.
- `KafkaMessagePublisher` publica mensagens da Outbox.
- `ShipmentCreationHandler` grava `shipment.created` na Outbox.

Ressalva crítica para E2E local:

- `appsettings.Development.json` mantém `FeatureFlags:UseMockShipmentRepository = true`, mas `ShipmentCreationHandler` depende diretamente de `ShipmentDbContext`, `InboxMessages`, `Shipments`, transação e Outbox.
- Ou seja: mesmo com repository mock ligado, o fluxo Kafka de criação de shipment ainda exige banco real e schema aplicado.
- Para rodar E2E local, é necessário ter o banco/schema do `ShipmentService` funcionando ou refatorar o handler para usar portas abstraídas também para Inbox/Outbox/Unit of Work.

### TrackingService

PRs validados:

- `TrackingService#4` - `Implementar integração Kafka real com Confluent.Kafka`
- `TrackingService#5` - `Fix Kafka offset commit overload`

Implementação observada:

- Configuração `Kafka:BootstrapServers = localhost:9092` em `appsettings.Development.json`.
- `ConsumerGroupId = tracking-service`.
- Tópicos configurados: `shipment.created` e `shipment.status.updated`.
- `KafkaTrackingMessageConsumer` consome `shipment.created` e mapeia para evento interno de tracking.
- `KafkaIntegrationEventBus` publica `shipment.status.updated`.
- Correção de commit de offset aplicada usando `TopicPartitionOffset` em array.

Ressalva:

- `FeatureFlags:MockTrackingRepository:Enabled = true` em Development, mas `Program.cs` ainda registra `TrackingDbContext` e health check de DB.
- Se o banco não existir, `/health` pode falhar mesmo em modo mock.

### NotificationService

PR validado:

- `NotificationService#5` - `Implement Kafka notification consumers`

Implementação observada:

- Configuração `Kafka:BootstrapServers = localhost:9092` em `appsettings.Development.json`.
- `ConsumerGroupId = notification-service`.
- Tópicos configurados: `order.created`, `shipment.created`, `shipment.status.updated`.
- `KafkaNotificationConsumer` assina os três tópicos canônicos.
- Valida envelope, lê `eventType`, `eventId`, `correlationId` e despacha para `NotificationPlanner`.

Ressalva:

- Não há producer Kafka neste serviço; isso está correto para o escopo atual.
- Health check de DB permanece registrado no readiness, mesmo com `MockNotificationRepository` ativo em Development.

### ShippingPromiseService

PR validado:

- `ShippingPromiseService#7` - `Add Kafka publisher for shipping.promise.calculated events`

Implementação observada:

- Configuração `Kafka:BootstrapServers = localhost:9092` em `appsettings.Development.json`.
- `ConsumerGroupId = shipping-promise-service`.
- Tópico configurado: `shipping.promise.calculated`.
- `Program.cs` registra `KafkaOptions` com validação e `KafkaShippingPromiseEventPublisher` como `IShippingPromiseEventPublisher`.
- Publicação best-effort preserva o fluxo HTTP síncrono.

Status: OK.

### CheckoutService

Validação observada:

- Não foi detectada implementação Kafka ou dependência `Confluent.Kafka` no código atual.
- Não foi encontrado PR recente de Kafka para `CheckoutService`.

Impacto:

- O ciclo `checkout.shipping.quote.requested` -> `shipping.promise.calculated` ainda não está completo no código.
- Para E2E local focado em `order.created` -> `shipment.created` -> `shipment.status.updated` -> notification, o CheckoutService pode ficar fora inicialmente.
- Para E2E completo desde cotação/promise via Kafka, o CheckoutService precisa implementar producer/consumer Kafka conforme contrato.

## Validação de compatibilidade com docker-compose

O `docker-compose.yml` do repo de arquitetura está compatível com as configurações dos serviços:

- Kafka expõe `localhost:9092` para aplicações rodando fora do Docker.
- Kafka UI expõe `http://localhost:8088`.
- Kafka UI aponta internamente para `kafka:29092`.

## Bloqueios para E2E local real

### Bloqueio 1 - Banco/schemas

Alguns serviços registram `DbContext` e usam Outbox/Inbox reais mesmo com mocks habilitados.

Serviços com maior risco:

- `ShipmentService`
- `TrackingService`
- `NotificationService`
- `OrderService`

Para E2E real, existem duas opções:

1. Aplicar schemas no Postgres local para cada serviço.
2. Criar modo E2E local com mocks também para Inbox/Outbox/Unit of Work.

### Bloqueio 2 - CheckoutService ainda sem Kafka

Sem Kafka no CheckoutService, a cadeia de cotação/promise assíncrona ainda não fecha.

### Bloqueio 3 - Tópicos internos de saga não documentados

O `OrderService` ainda usa tópicos internos como:

- `inventory.commands`
- `fulfillment.commands`
- `payment.commands`
- `shipment.commands`
- `order.events`

Esses tópicos não constam no contrato canônico atual. Devem ser documentados ou substituídos por tópicos canônicos.

## Recomendação de execução local por fases

### Fase 1 - Kafka básico

Validar publicação e consumo com estes tópicos:

```text
order.created
shipment.created
shipment.status.updated
```

Serviços mínimos:

```text
OrderService
ShipmentService
TrackingService
NotificationService
```

### Fase 2 - Promise assíncrona

Adicionar:

```text
ShippingPromiseService
```

Validar publicação de:

```text
shipping.promise.calculated
```

### Fase 3 - Checkout assíncrono completo

Implementar Kafka no:

```text
CheckoutService
```

Validar:

```text
checkout.shipping.quote.requested
shipping.promise.calculated
```

## Comandos de validação local

Criar tópicos manualmente, se necessário:

```bash
docker exec -it logistica-envios-kafka kafka-topics --bootstrap-server localhost:9092 --create --topic order.created --partitions 1 --replication-factor 1

docker exec -it logistica-envios-kafka kafka-topics --bootstrap-server localhost:9092 --create --topic shipment.created --partitions 1 --replication-factor 1

docker exec -it logistica-envios-kafka kafka-topics --bootstrap-server localhost:9092 --create --topic shipment.status.updated --partitions 1 --replication-factor 1

docker exec -it logistica-envios-kafka kafka-topics --bootstrap-server localhost:9092 --create --topic shipping.promise.calculated --partitions 1 --replication-factor 1

docker exec -it logistica-envios-kafka kafka-topics --bootstrap-server localhost:9092 --create --topic checkout.shipping.quote.requested --partitions 1 --replication-factor 1
```

Listar tópicos:

```bash
docker exec -it logistica-envios-kafka kafka-topics --bootstrap-server localhost:9092 --list
```

Abrir UI:

```text
http://localhost:8088
```

## Parecer final

As alterações estão bem direcionadas e seguem a intenção arquitetural de E2E local com Kafka, especialmente nos fluxos de pedido, shipment, tracking e notification.

O estado atual já permite avançar para testes locais de Kafka, mas não garante E2E completo sem preparação de banco/schema ou ajustes adicionais de mocks transacionais.

Para fechar a integridade da solução, faltam:

1. Implementar Kafka no `CheckoutService`.
2. Decidir/documentar tópicos internos de saga usados pelo `OrderService`.
3. Corrigir health checks em modo mock.
4. Garantir schemas locais para serviços com Outbox/Inbox reais.
5. Rodar `dotnet restore`, `dotnet build`, `dotnet test` em ambiente com .NET 8.
