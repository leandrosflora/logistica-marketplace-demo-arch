# Runbook - Order Visibility local

## Objetivo

Guiar a execução local do `OrderVisibilityService` e do Order Monitor (`MarketplaceWeb` em `/admin/operations/orders`), permitindo reproduzir uma jornada de pedido do zero e investigá-la ponta a ponta (status, timeline, trace, métricas).

## 1. Subir Kafka, Postgres, Jaeger, Prometheus e Grafana

No repositório `meli-envios-architecture`:

```bash
docker compose --profile observability up -d
```

Isso sobe `kafka`, `kafka-ui`, `redis`, `postgres`, `jaeger`, `prometheus` e `grafana`. Validar:

```bash
docker compose ps
```

| Recurso | Endereço |
|---|---|
| Kafka UI | http://localhost:8088 |
| Jaeger UI | http://localhost:16686 |
| Prometheus | http://localhost:9090 |
| Grafana | http://localhost:3003 (usuário `admin`, senha `logistica`) |
| Postgres | `localhost:5432` (db `logistica_envios`, usuário/senha `logistica`) |

> Se o volume do Postgres já existia antes desta mudança, o novo schema `order_visibility` (adicionado em `database/logistica-envios-init.sql`) só é aplicado recriando o volume: `docker compose down -v && docker compose --profile observability up -d`. Alternativamente, aplique manualmente o trecho `CREATE SCHEMA order_visibility ...` do script contra o Postgres em execução.

Crie os tópicos consumidos pelo `OrderVisibilityService` que ainda não existirem localmente (siga `docs/runbooks/kafka-local-e2e.md` para a lista completa e o comando `kafka-topics --create`).

## 2. Subir o `OrderVisibilityService`

No repositório principal (`meli`):

```bash
cd OrderVisibilityService
dotnet run
```

Por padrão sobe em `http://localhost:48930` (Swagger em `/swagger`, métricas em `/metrics`, health em `/health`, hub SignalR em `/order-journeys/hub`). Confirme nos logs que o `OrderJourneyEventsConsumer` assinou os tópicos e que `OrderVisibilityDb` conectou.

## 3. Subir os demais serviços da saga e o `MarketplaceWeb`

Suba pelo menos `CheckoutService`, `OrderService`, `InventoryService`, `FulfillmentCenterService`, `PaymentService`, `ShipmentService`, `TrackingService` (cada um com `dotnet run` no seu diretório) e `MarketplaceWeb`:

```bash
cd MarketplaceWeb
dotnet run
```

Confirme em `MarketplaceWeb/appsettings.Development.json` (ou `appsettings.json`) que `OrderVisibility:BaseUrl` aponta para `http://localhost:48930` e que `Jaeger:BaseUrl` aponta para `http://localhost:16686`.

## 4. Gerar uma jornada de pedido

**Fluxo real**: use o fluxo normal de checkout (via `MarketplaceWeb` ou diretamente pelos `*.http` de `CheckoutService`) para confirmar um checkout. Isso dispara `checkout.confirmed` → saga do `OrderService` → eventos de inventory/fulfillment/payment/shipment/tracking, todos consumidos pelo `OrderVisibilityService` em tempo real.

**Cenários sintéticos**: use `scripts/order-visibility-demo.sh` para publicar eventos diretamente no Kafka sem depender dos outros serviços estarem rodando (útil para testar o `OrderVisibilityService` e a tela isoladamente):

```bash
./scripts/order-visibility-demo.sh happy              # checkout -> ... -> in_transit
./scripts/order-visibility-demo.sh inventory-failed    # falha na reserva de estoque
./scripts/order-visibility-demo.sh payment-rejected    # pagamento recusado
./scripts/order-visibility-demo.sh stuck               # para após inventory.reserved; aguarde 60s+
```

O script gera `correlationId`/`checkoutId`/`orderId` novos a cada execução e imprime os valores usados, para consulta posterior na tela ou via API.

## 5. Abrir a tela operacional

Acesse `http://localhost:5130/admin/operations/orders` (ou a porta configurada em `MarketplaceWeb`). A lista atualiza sozinha a cada ~4s (polling; ver nota abaixo sobre SignalR). Use os filtros de status, erro, travados, orderId, checkoutId, correlationId, buyerId, sellerId.

> **Nota sobre realtime**: o hub SignalR (`/order-journeys/hub`) está implementado no `OrderVisibilityService`, mas o cliente JS do `MarketplaceWeb` ainda não foi conectado a ele — trazer um cliente de terceiros (`@microsoft/signalr`) para `wwwroot` exigiria passar pelo processo normal de dependências do time (npm/libman com revisão), o que não foi feito nesta mudança. A lista funciona hoje via polling da API REST, que já entrega a mesma informação com um atraso de poucos segundos.

## 6. Buscar pedido por `orderId`

Na lista, clique no `orderId` da linha desejada, ou acesse diretamente `GET /order-journeys/{orderId}` no `OrderVisibilityService` (via Swagger ou `OrderVisibilityService.http`). Isso abre a tela de detalhe com a timeline vertical completa.

## 7. Buscar por `correlationId`

Antes de existir `orderId` (janela entre `checkout.confirmed` e `order.created`), use `GET /order-journeys/by-correlation/{correlationId}` — o `correlationId` está disponível desde a confirmação do checkout. Depois que `order.created` chega, a mesma jornada passa a responder também em `GET /order-journeys/{orderId}`.

## 8. Abrir trace no Jaeger

Na tela de detalhe, cada evento da timeline tem um botão/link "Ver trace":

- Se o evento tiver `traceId` (hoje, apenas eventos produzidos por `CheckoutService` e `FulfillmentCenterService` — ver tabela de adoção em `docs/contracts/kafka-events.md`), o link abre o trace diretamente em `{Jaeger}/trace/{traceId}`.
- Caso contrário, abre uma busca por `correlation.id=<correlationId>` em `{Jaeger}/search?tags=...`.

## 9. Identificar pedido travado

Use o filtro "Somente travados" na lista (equivalente a `GET /order-journeys/stuck?olderThanSeconds=60`). O `StuckJourneyWorker` reavalia essa consulta a cada 15s (configurável em `StuckJourney:PollIntervalSeconds`) e emite o alerta Prometheus `OrderJourneyStuck` quando `order_journey_stuck_total > 0` por mais de 1 minuto (ver `monitoring/alerts/order-visibility-alerts.yml`).

## 10. Investigar erro de evento

Jornadas com erro aparecem destacadas (linha vermelha) na lista e têm `hasError=true`/`errorReason` preenchido. Na tela de detalhe, expanda o evento de falha (`inventory.reservation.failed`, `fulfillment.capacity.failed`, `payment.rejected`, `payment.capture.failed`) para ver o payload completo, tópico, partition/offset e o serviço produtor. Eventos com `eventId`/`correlationId` ausentes são descartados ("quarantined") com um log de `Warning` no `OrderVisibilityService` — procure por "Quarantining" nos logs para encontrá-los.

## Validar métricas no Prometheus

Acesse `http://localhost:9090` e consulte, por exemplo:

```promql
order_journey_events_consumed_total
order_journey_status_total
order_journey_failed_total
order_journey_stuck_total
order_journey_duration_seconds_bucket
order_journey_step_duration_seconds_bucket
order_journey_consumer_lag
```

Em `http://localhost:9090/alerts` é possível ver o estado das regras de `monitoring/alerts/order-visibility-alerts.yml`. No Grafana (`http://localhost:3003`), os dashboards "Order Journey Overview" e "Kafka Journey Health" já vêm provisionados na pasta "Logística Envios".

## Limitações conhecidas desta versão

- `order_journey_consumer_lag` é um total agregado entre todas as partitions assinadas, não quebrado por tópico.
- `order_journey_step_duration_seconds` mede a duração de um único salto (status atual → próximo evento recebido), não o caminho completo entre dois eventos não-adjacentes (ex.: `order.created` → `shipment.created` passa por vários saltos intermediários).
- O cliente realtime do Order Monitor usa polling, não o hub SignalR (ver nota na seção 5).
- `traceId`/`spanId` no envelope hoje só são populados por `CheckoutService` e `FulfillmentCenterService`; os demais produtores caem no fallback de busca por `correlationId` no Jaeger.
