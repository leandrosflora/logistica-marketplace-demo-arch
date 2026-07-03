# Runbook - Kafka local E2E

## Objetivo

Validar localmente a comunicação Kafka **que existe no código atual** dos microservices do case Logística Envios.

## Status atual

Status: **E2E parcial**.

O fluxo está implementado até:

```text
Checkout -> Shipping Promise -> Checkout -> Order -> Inventory/Fulfillment -> Shipment -> Tracking/Notification
```

Há lacunas conhecidas:

| Lacuna | Impacto |
|---|---|
| `PaymentService` não existe | `OrderService` produz `payment.commands`, mas não há consumer real. |
| `AuditService` não existe | Auditoria centralizada de eventos não deve ser validada neste E2E. |
| Alguns tópicos de notificação não têm producer atual | `order.confirmed`, `order.cancelled`, `payment.rejected` e `shipment.cancelled` estão configurados como entrada do `NotificationService`, mas não têm producer canônico localizado. |

## Microservices com Kafka implementado

| Serviço | Producer/outbox | Consumer(s) registrado(s) | Status |
|---|---|---|---|
| `CheckoutService` | `checkout.shipping.quote.requested`, `checkout.confirmed` | `ShippingPromiseCalculatedConsumer` | Implementado |
| `ShippingPromiseService` | `shipping.promise.calculated` | `ShippingQuoteRequestedConsumer` | Implementado |
| `OrderService` | `order.created`, `inventory.commands`, `fulfillment.commands`, `payment.commands`, `shipment.commands`, `order.events` | `CheckoutConfirmedConsumer`, `InventoryReservedConsumer`, `InventoryReservationFailedConsumer`, `FulfillmentCapacityReservedConsumer`, `FulfillmentCapacityFailedConsumer`, `ShipmentCreatedConsumer`, `ShipmentStatusUpdatedConsumer` | Implementado/parcial |
| `InventoryService` | `inventory.reserved`, `inventory.reservation.confirmed`, `inventory.reservation.failed`, `inventory.reservation.released` | `InventoryCommandsConsumer` | Implementado |
| `FulfillmentCenterService` | `fulfillment.capacity.reserved`, `fulfillment.capacity.confirmed`, `fulfillment.capacity.failed` | `FulfillmentCommandsConsumer` | Implementado |
| `ShipmentService` | `shipment.created`, `carrier-shipment.commands` | `OrderCreatedKafkaConsumer`, `ShipmentCommandsConsumer` | Implementado/parcial |
| `TrackingService` | `shipment.status.updated` | `TrackingConsumerWorker` / consumer de `shipment.created` | Implementado |
| `NotificationService` | Sem evento canônico publicado | `KafkaNotificationConsumer` | Consumer implementado; alguns tópicos dependem de producers ausentes |

## Endpoints locais

| Recurso | Endereço |
|---|---|
| Kafka UI | `http://localhost:8088` |
| Kafka broker para apps locais | `localhost:9092` |
| Kafka broker para containers no compose | `kafka:29092` |
| Redis local | `localhost:6379` |
| Postgres local | `localhost:5432` |

Importante: `http://localhost:8088` é só a interface web do Kafka UI. Microservices devem apontar para `localhost:9092` quando rodam fora do Docker.

## Subir infraestrutura

No repo `logistica-envios-demo-arch`:

```bash
docker compose up -d
```

Validar containers:

```bash
docker compose ps
```

> **Atenção — mudanças em `database/logistica-envios-init.sql`**: esse script só é
> executado pelo Postgres na primeira inicialização de um volume de dados vazio
> (`docker-entrypoint-initdb.d`). Se você já rodou `docker compose up -d` antes e alterou
> `logistica-envios-init.sql` (ex.: correções de schema para o `InventoryService`/
> `FulfillmentCenterService`), o volume existente **não** será atualizado automaticamente.
> Recrie o volume para aplicar o novo script:
>
> ```bash
> docker compose down -v
> docker compose up -d
> ```
>
> Alternativamente, aplique manualmente os `ALTER TABLE` novos contra o Postgres em
> execução (`docker exec -it logistica-envios-postgres psql -U logistica -d logistica_envios`).

## Criar tópicos implementados

```bash
docker exec -it logistica-envios-kafka kafka-topics --bootstrap-server localhost:9092 --create --if-not-exists --topic checkout.shipping.quote.requested --partitions 1 --replication-factor 1

docker exec -it logistica-envios-kafka kafka-topics --bootstrap-server localhost:9092 --create --if-not-exists --topic shipping.promise.calculated --partitions 1 --replication-factor 1

docker exec -it logistica-envios-kafka kafka-topics --bootstrap-server localhost:9092 --create --if-not-exists --topic checkout.confirmed --partitions 1 --replication-factor 1

docker exec -it logistica-envios-kafka kafka-topics --bootstrap-server localhost:9092 --create --if-not-exists --topic order.created --partitions 1 --replication-factor 1

docker exec -it logistica-envios-kafka kafka-topics --bootstrap-server localhost:9092 --create --if-not-exists --topic inventory.commands --partitions 1 --replication-factor 1

docker exec -it logistica-envios-kafka kafka-topics --bootstrap-server localhost:9092 --create --if-not-exists --topic inventory.reserved --partitions 1 --replication-factor 1

docker exec -it logistica-envios-kafka kafka-topics --bootstrap-server localhost:9092 --create --if-not-exists --topic inventory.reservation.confirmed --partitions 1 --replication-factor 1

docker exec -it logistica-envios-kafka kafka-topics --bootstrap-server localhost:9092 --create --if-not-exists --topic inventory.reservation.failed --partitions 1 --replication-factor 1

docker exec -it logistica-envios-kafka kafka-topics --bootstrap-server localhost:9092 --create --if-not-exists --topic inventory.reservation.released --partitions 1 --replication-factor 1

docker exec -it logistica-envios-kafka kafka-topics --bootstrap-server localhost:9092 --create --if-not-exists --topic fulfillment.commands --partitions 1 --replication-factor 1

docker exec -it logistica-envios-kafka kafka-topics --bootstrap-server localhost:9092 --create --if-not-exists --topic fulfillment.capacity.reserved --partitions 1 --replication-factor 1

docker exec -it logistica-envios-kafka kafka-topics --bootstrap-server localhost:9092 --create --if-not-exists --topic fulfillment.capacity.confirmed --partitions 1 --replication-factor 1

docker exec -it logistica-envios-kafka kafka-topics --bootstrap-server localhost:9092 --create --if-not-exists --topic fulfillment.capacity.failed --partitions 1 --replication-factor 1

docker exec -it logistica-envios-kafka kafka-topics --bootstrap-server localhost:9092 --create --if-not-exists --topic fulfillment.capacity.released --partitions 1 --replication-factor 1

docker exec -it logistica-envios-kafka kafka-topics --bootstrap-server localhost:9092 --create --if-not-exists --topic fulfillment.capacity.reservation.expired --partitions 1 --replication-factor 1

docker exec -it logistica-envios-kafka kafka-topics --bootstrap-server localhost:9092 --create --if-not-exists --topic payment.commands --partitions 1 --replication-factor 1

docker exec -it logistica-envios-kafka kafka-topics --bootstrap-server localhost:9092 --create --if-not-exists --topic shipment.commands --partitions 1 --replication-factor 1

docker exec -it logistica-envios-kafka kafka-topics --bootstrap-server localhost:9092 --create --if-not-exists --topic shipment.created --partitions 1 --replication-factor 1

docker exec -it logistica-envios-kafka kafka-topics --bootstrap-server localhost:9092 --create --if-not-exists --topic shipment.status.updated --partitions 1 --replication-factor 1

docker exec -it logistica-envios-kafka kafka-topics --bootstrap-server localhost:9092 --create --if-not-exists --topic carrier-shipment.commands --partitions 1 --replication-factor 1

docker exec -it logistica-envios-kafka kafka-topics --bootstrap-server localhost:9092 --create --if-not-exists --topic order.events --partitions 1 --replication-factor 1
```

## Tópicos configurados, mas não comprovados como E2E

Crie apenas se quiser observar consumers configurados ou preparar evolução futura:

```bash
docker exec -it logistica-envios-kafka kafka-topics --bootstrap-server localhost:9092 --create --if-not-exists --topic order.confirmed --partitions 1 --replication-factor 1

docker exec -it logistica-envios-kafka kafka-topics --bootstrap-server localhost:9092 --create --if-not-exists --topic order.cancelled --partitions 1 --replication-factor 1

docker exec -it logistica-envios-kafka kafka-topics --bootstrap-server localhost:9092 --create --if-not-exists --topic payment.rejected --partitions 1 --replication-factor 1

docker exec -it logistica-envios-kafka kafka-topics --bootstrap-server localhost:9092 --create --if-not-exists --topic shipment.cancelled --partitions 1 --replication-factor 1

docker exec -it logistica-envios-kafka kafka-topics --bootstrap-server localhost:9092 --create --if-not-exists --topic shipment.creation.failed --partitions 1 --replication-factor 1
```

Esses tópicos não devem ser usados como prova de E2E completo sem alteração/validação do código produtor.

## Listar tópicos

```bash
docker exec -it logistica-envios-kafka kafka-topics --bootstrap-server localhost:9092 --list
```

## Smoke test manual

Consumer:

```bash
docker exec -it logistica-envios-kafka kafka-console-consumer \
  --bootstrap-server localhost:9092 \
  --topic order.created \
  --from-beginning
```

Producer:

```bash
docker exec -it logistica-envios-kafka kafka-console-producer \
  --bootstrap-server localhost:9092 \
  --topic order.created
```

## Ordem recomendada por fases

### Fase 0 — Infraestrutura

1. Subir Kafka, Kafka UI, Redis e Postgres.
2. Criar os tópicos implementados.
3. Validar os tópicos no Kafka UI.

### Fase 1 — Promise assíncrona

Rodar:

```text
CheckoutService
ShippingPromiseService
```

Esperado:

1. `CheckoutService` publica `checkout.shipping.quote.requested`.
2. `ShippingPromiseService` consome e publica `shipping.promise.calculated`.
3. `CheckoutService` consome `shipping.promise.calculated`.

### Fase 2 — Confirmação de checkout e criação de pedido

Rodar:

```text
CheckoutService
OrderService
```

Esperado:

1. `CheckoutService` publica `checkout.confirmed`.
2. `OrderService` consome e cria `Order`.
3. `OrderService` publica `order.created`, `inventory.commands` e `fulfillment.commands`.

### Fase 3 — Estoque e fulfillment

Rodar:

```text
InventoryService
FulfillmentCenterService
OrderService
```

Esperado:

1. `InventoryService` consome `inventory.commands`.
2. `InventoryService` publica eventos de reserva.
3. `FulfillmentCenterService` consome `fulfillment.commands`.
4. `FulfillmentCenterService` publica eventos de capacidade.
5. `OrderService` consome respostas e escreve `payment.commands` quando a saga chega na etapa de pagamento.

### Fase 4 — Lacuna de pagamento

O E2E real para pagamento **não fecha** no estado atual.

Motivo:

- `OrderService` produz `payment.commands`;
- não existe `PaymentService` implementado;
- não há consumer de pagamento registrado no `Program.cs` do `OrderService` atual.

Resultado esperado nesta fase: observar `payment.commands` no Kafka e registrar a lacuna.

### Fase 5 — Shipment, tracking e notification

Rodar:

```text
ShipmentService
TrackingService
NotificationService
```

Esperado nos trechos implementados:

1. `ShipmentService` consome `order.created` e/ou `shipment.commands`.
2. `ShipmentService` publica `shipment.created`.
3. `TrackingService` consome `shipment.created`.
4. `TrackingService` publica `shipment.status.updated` ao receber atualização de tracking.
5. `NotificationService` consome `order.created`, `shipment.created` e `shipment.status.updated`.

## Critério de sucesso realista

O teste é considerado válido quando comprovar:

- publicação/consumo entre Checkout e Shipping Promise;
- criação de pedido via `checkout.confirmed`;
- comandos de inventory e fulfillment emitidos pelo Order;
- respostas de inventory e fulfillment consumidas pelo Order;
- geração de `payment.commands` como lacuna explícita;
- criação de shipment a partir de `order.created` ou `shipment.commands`;
- publicação de `shipment.created`;
- atualização de tracking via `shipment.status.updated`;
- consumo de eventos implementados pelo Notification.

Não considerar como sucesso obrigatório:

- `PaymentService`;
- `AuditService`;
- `payment.approved` / `payment.rejected`;
- `shipment.cancelled`;
- `order.confirmed` / `order.cancelled` como tópicos canônicos.

Esses pontos dependem de código adicional ou ajuste nos producers/consumers.

## Validação da jornada de compra (seed de 20 produtos)

`logistica-envios-init.sql` semeia 20 produtos em `product_catalog.products`
(`11111111-1111-1111-1111-111111111111` a `...130`), com estoque em
`inventory.inventory_items` para todos eles. Isso é suficiente para exercitar
cálculo de frete/prazo/rota para o catálogo, não só para o produto demo original.

### Duas convenções de CEP — não misturar

O mesmo CEP de destino é interpretado de duas formas diferentes, dependendo do
serviço, e o seed respeita as duas:

| Serviço | Coluna | Convenção | Exemplo (`01310-100`) |
|---|---|---|---|
| `FulfillmentCenterService` (`fulfillment.center_coverages`) | `PostalCodeFrom`/`PostalCodeTo` | CEP menos os **2 primeiros dígitos** (`CandidateSearchService.NormalizePostalCode`, coberto por `CandidateSearchServiceTests.cs:47`) | `310100` |
| `RoutingService` (`routing.postal_coverages`) e `ShippingPricingService` (`pricing.postal_zones`) | idem | CEP **completo** de 8 dígitos (`RouteSearchService`/`ShippingPricingApplicationService.NormalizePostalCode`) | `1310100` |

Se um novo destino for adicionado ao seed, o intervalo de `center_coverages`
tem que ficar no espaço `0`–`999999`; os intervalos de `postal_coverages` e
`postal_zones` ficam no espaço do CEP completo. Misturar as duas quebra a
busca de candidatos silenciosamente (retorna lista vazia, não erro).

### Datas de capacidade e calendário são rolantes, não fixas

`fulfillment.capacity_slots` e `fulfillment.center_operation_schedules` são
gerados via `generate_series(CURRENT_DATE, CURRENT_DATE + 21 dias)` toda vez
que o script é aplicado — não uma data literal. `OperationalCalendarService`
só varre 14 dias a partir de "agora" e não tem fallback, então isso precisa
continuar cobrindo pelo menos essa janela.

### Casing do `carrier_code`

`CarrierService` normaliza o código do carrier para `UPPER_INVARIANT` antes de
comparar (`Carrier.Code`/`CarrierRepository.GetProfileAsync`). O seed guarda
`carrier.carriers."Code"` em maiúsculo (`CARRIER_1`, `CARRIER_2`) por esse
motivo, mesmo que `routing.logistics_lanes.carrier_code` continue em
minúsculo (`carrier_1`, `carrier_2`) — a normalização acontece na hora da
comparação, então a origem pode ficar em qualquer case.

### Checklist manual — golden path (produto leve, `carrier_1`, CEP `01310-100`)

1. `FulfillmentCenterService`: `POST /fulfillment-centers/candidates/search` com
   `sellerId=22222222-2222-2222-2222-222222222222`, `destinationPostalCode=01310-100`,
   `mode=1` (Fulfillment) → espera pelo menos 1 candidato (`FC-SP-01`).
2. `RoutingService`: `POST /v1/routes/calculate` com
   `originNodeId=33333333-3333-3333-3333-333333333333`, mesmo CEP → espera rota via
   `HUB-SP-CENTRO` → `LM-SP-ZS`, carrier `carrier_1`.
3. `CarrierService`: `POST /carrier-availability/search` para a rota acima → espera
   `available=true` (service level `same_day`, `SupportsRestrictedItems=true`).
4. `ShippingPricingService`: `POST /shipping-prices/quotes/batch` para a mesma
   combinação → espera preço calculado a partir do `rate_band` 0–2kg.
5. `ShippingPromiseService`: `POST` do fluxo completo com o produto
   `11111111-1111-1111-1111-111111111111` → espera `Available: true`.

### Checklist manual — produto pesado (>= 10kg, `carrier_2`, CEP `05700-000`)

Mesmos passos acima, mas com `sku=11111111-1111-1111-1111-111111111126`
(Kit Halteres 10kg Demo, 10.5kg), `destinationPostalCode=05700-000`. A rota
esperada é direta `FC-SP-01` → `LM-SP-057` (lane `carrier_2`/`standard`), e o
preço deve vir do `rate_band` 0–15kg da zona `SP-057` (o `rate_band` original
só cobria até 2kg). Uma cadeia completa checkout→tracking→notification já
está seedada para esse caso (`checkout.checkouts.id =
12121212-1212-1212-1212-121212121201`), útil para inspecionar o resultado
esperado sem precisar rodar o fluxo do zero.

### Produto restrito — validação negativa, não jornada completa

3 produtos têm `is_restricted = true` (baterias de lítio):
`...112`, `...114`, `...129`. **Não existe cadeia completa seedada para eles**:
`ShippingPromiseApplicationService.CalculateAsync` retorna `Unavailable` assim
que vê `IsRestricted = true`, antes de chamar Fulfillment/Routing/Carrier/Pricing.
Para observar a diferenciação por restrição, chame `CarrierService` diretamente:
o service level `same_day` (`carrier_1`) tem `SupportsRestrictedItems=true`; o
`standard` (`carrier_2`) tem `SupportsRestrictedItems=false` — o mesmo pacote
restrito deve ser aceito por um e rejeitado pelo outro.
