# Runbook - Kafka local E2E

## Objetivo

Executar e validar localmente a comunicação Kafka entre os microservices do case Meli Envios.

## Endpoints locais

| Recurso | Endereço |
|---|---|
| Kafka UI | `http://localhost:8088` |
| Kafka broker para apps locais | `localhost:9092` |
| Kafka broker para containers no compose | `kafka:29092` |

Importante: `http://localhost:8088` é apenas a interface web do Kafka UI. Microservices não devem apontar para `8088`; devem usar `localhost:9092` quando rodando fora do Docker.

## Subir infraestrutura

No repo `meli-envios-architecture`:

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

```bash
docker exec -it meli-envios-kafka kafka-topics --bootstrap-server localhost:9092 --create --topic checkout.shipping.quote.requested --partitions 1 --replication-factor 1

docker exec -it meli-envios-kafka kafka-topics --bootstrap-server localhost:9092 --create --topic shipping.promise.calculated --partitions 1 --replication-factor 1

docker exec -it meli-envios-kafka kafka-topics --bootstrap-server localhost:9092 --create --topic order.created --partitions 1 --replication-factor 1

docker exec -it meli-envios-kafka kafka-topics --bootstrap-server localhost:9092 --create --topic shipment.created --partitions 1 --replication-factor 1

docker exec -it meli-envios-kafka kafka-topics --bootstrap-server localhost:9092 --create --topic shipment.status.updated --partitions 1 --replication-factor 1
```

Se o tópico já existir, o comando pode retornar erro de tópico existente. Isso não bloqueia o teste.

Listar tópicos:

```bash
docker exec -it meli-envios-kafka kafka-topics --bootstrap-server localhost:9092 --list
```

## Microservices com Kafka implementado

| Serviço | Producer | Consumer | Consumer group |
|---|---|---|---|
| `OrderService` | `order.created` | `shipment.status.updated` | `order-service` |
| `ShipmentService` | `shipment.created` | `order.created` | `shipment-service` |
| `TrackingService` | `shipment.status.updated` | `shipment.created` | `tracking-service` |
| `NotificationService` | - | `order.created`, `shipment.created`, `shipment.status.updated` | `notification-service` |
| `ShippingPromiseService` | `shipping.promise.calculated` | - | `shipping-promise-service` |

Pendente:

| Serviço | Pendência |
|---|---|
| `CheckoutService` | Implementar producer `checkout.shipping.quote.requested` e consumer `shipping.promise.calculated` |

## Ordem recomendada para teste por fases

### Fase 1 - Pedido, shipment, tracking e notification

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

Objetivo:

1. `OrderService` publica `order.created`.
2. `ShipmentService` consome `order.created` e publica `shipment.created`.
3. `TrackingService` consome `shipment.created` e publica `shipment.status.updated`.
4. `NotificationService` consome os três eventos.

### Fase 2 - Promise assíncrona

Adicionar:

```text
ShippingPromiseService
```

Tópico usado:

```text
shipping.promise.calculated
```

### Fase 3 - Checkout assíncrono completo

Adicionar após implementação Kafka:

```text
CheckoutService
```

Tópicos:

```text
checkout.shipping.quote.requested
shipping.promise.calculated
```

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

## Pontos de atenção

1. Alguns serviços ainda usam `DbContext`, `Inbox` e `Outbox` reais mesmo com repository mock habilitado.
2. Para E2E real, aplique os schemas locais ou crie mocks transacionais para Inbox/Outbox.
3. O `OrderService` ainda possui tópicos internos de saga não documentados no contrato canônico atual: `inventory.commands`, `fulfillment.commands`, `payment.commands`, `shipment.commands`, `order.events`.
4. `CheckoutService` ainda não fecha o fluxo Kafka de quote/promise.

## Validação visual

No Kafka UI:

1. Acesse `http://localhost:8088`.
2. Abra o cluster `local`.
3. Verifique os tópicos.
4. Acompanhe mensagens nos tópicos canônicos.
5. Confira consumer groups:
   - `order-service`
   - `shipment-service`
   - `tracking-service`
   - `notification-service`
   - `shipping-promise-service`

## Comandos úteis

Consumir mensagens diretamente:

```bash
docker exec -it meli-envios-kafka kafka-console-consumer --bootstrap-server localhost:9092 --topic order.created --from-beginning
```

Publicar mensagem manual:

```bash
docker exec -it meli-envios-kafka kafka-console-producer --bootstrap-server localhost:9092 --topic order.created
```

Resetar ambiente:

```bash
docker compose down -v
docker compose up -d
```
