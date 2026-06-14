# Runbook - Kafka local E2E

## Objetivo

Executar e validar localmente a comunicação Kafka entre os microservices do case Meli Envios.

## Status atual

Status: **parcialmente pronto**.

A infraestrutura Kafka local está pronta, mas o E2E completo ainda depende de alinhamento de payload entre producers e consumers.

Revisão relacionada: [`docs/reviews/kafka-e2e-contract-review-2026-06-14.md`](../reviews/kafka-e2e-contract-review-2026-06-14.md).

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

## Criar tópicos internos de saga do OrderService

Esses tópicos foram formalizados pela [`ADR-0001`](../adr/0001-order-service-internal-saga-topics.md).

```bash
docker exec -it meli-envios-kafka kafka-topics --bootstrap-server localhost:9092 --create --topic inventory.commands --partitions 1 --replication-factor 1

docker exec -it meli-envios-kafka kafka-topics --bootstrap-server localhost:9092 --create --topic fulfillment.commands --partitions 1 --replication-factor 1

docker exec -it meli-envios-kafka kafka-topics --bootstrap-server localhost:9092 --create --topic payment.commands --partitions 1 --replication-factor 1

docker exec -it meli-envios-kafka kafka-topics --bootstrap-server localhost:9092 --create --topic shipment.commands --partitions 1 --replication-factor 1

docker exec -it meli-envios-kafka kafka-topics --bootstrap-server localhost:9092 --create --topic order.events --partitions 1 --replication-factor 1
```

Se o tópico já existir, o comando pode retornar erro de tópico existente. Isso não bloqueia o teste.

Listar tópicos:

```bash
docker exec -it meli-envios-kafka kafka-topics --bootstrap-server localhost:9092 --list
```

## Microservices com Kafka implementado

| Serviço | Producer | Consumer | Consumer group | Status |
|---|---|---|---|---|
| `CheckoutService` | `checkout.shipping.quote.requested` | `shipping.promise.calculated` | `checkout-service` | Parcial: consumer apenas em modo DB-backed |
| `ShippingPromiseService` | `shipping.promise.calculated` | - | `shipping-promise-service` | Parcial: não consome `checkout.shipping.quote.requested` |
| `OrderService` | `order.created` e tópicos internos de saga | `shipment.status.updated` | `order-service` | Parcial: payload incompatível com consumers atuais |
| `ShipmentService` | `shipment.created` | `order.created` | `shipment-service` | Parcial: espera payload mais rico que o publicado pelo `OrderService` |
| `TrackingService` | `shipment.status.updated` | `shipment.created` | `tracking-service` | Parcial: não propaga `orderId`/`buyerId` para status |
| `NotificationService` | - | `order.created`, `shipment.created`, `shipment.status.updated` | `notification-service` | Parcial: depende de campos ausentes em alguns eventos |

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
order.created
shipment.created
shipment.status.updated
```

Use `kafka-console-producer` e `kafka-console-consumer` para validar conectividade básica.

### Fase 2 - Pedido, shipment, tracking e notification

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

1. `OrderService` publica `order.created`.
2. `ShipmentService` consome `order.created` e publica `shipment.created`.
3. `TrackingService` consome `shipment.created` e publica `shipment.status.updated`.
4. `NotificationService` consome os três eventos.
5. `OrderService` consome `shipment.status.updated`.

Bloqueio atual:

- O payload de `order.created` publicado pelo `OrderService` não contém todos os campos que o `ShipmentService` espera.
- O payload de `shipment.status.updated` publicado pelo `TrackingService` não contém todos os campos que `OrderService` e `NotificationService` esperam.

### Fase 3 - Promise assíncrona

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

1. `CheckoutService` publica `checkout.shipping.quote.requested`.
2. `ShippingPromiseService` consome `checkout.shipping.quote.requested`.
3. `ShippingPromiseService` publica `shipping.promise.calculated`.
4. `CheckoutService` consome `shipping.promise.calculated`.

Bloqueio atual:

- `ShippingPromiseService` ainda não possui consumer Kafka para `checkout.shipping.quote.requested`.
- `shipping.promise.calculated` não contém `checkoutId`, que é exigido pela projeção do `CheckoutService`.
- Em `CheckoutService`, o consumer de `shipping.promise.calculated` só é registrado em modo DB-backed; em mock mode, o serviço publica no Kafka, mas não consome a promise de retorno.

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
3. O `OrderService` possui tópicos internos de saga documentados pela ADR-0001.
4. Os contratos Kafka precisam ser alinhados antes do E2E completo.
5. Rode `dotnet restore`, `dotnet build` e `dotnet test` em todos os microservices antes do teste integrado.

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
