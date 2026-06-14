# Validação geral dos PRs recentes - Microservices Meli Envios

Data: 2026-06-14

## Escopo

Validação estática dos PRs recentes nos repositórios de microservices, BFF e frontend ligados ao case Meli Envios.

Foram revisados principalmente:

- PRs de mocks por feature flag para desenvolvimento local.
- PRs de alinhamento de contratos HTTP entre BFF, Shipping Promise e downstreams.
- Configurações `appsettings.json` e `appsettings.Development.json`.
- Registros de dependência em `Program.cs`.
- Endpoints/clients críticos para Order, Shipment e Tracking.

## Resultado executivo

Status geral: **OK com ressalvas operacionais**.

Não foi encontrada quebra crítica de contrato HTTP nos PRs mais recentes. As correções de BFF e Shipping Promise permanecem alinhadas com o contrato canônico. Os mocks por feature flag seguem a direção arquitetural correta para facilitar execução local sem banco completo.

As ressalvas são:

1. Nem todos os PRs tiveram `dotnet build`/`dotnet test` executados no ambiente do Codex, porque o runtime .NET não estava disponível no ambiente em vários PRs.
2. Alguns serviços continuam registrando `DbContext` e health check de banco mesmo quando usam repository mock em Development.
3. `ProductCatalogService` ficou 100% mockado no `Program.cs`, sem feature flag para alternar para implementação real.
4. Existe um PR aberto e draft no `MarketplaceWeb.Bff` apenas de ajuste documental da URL local do Product Search.

## PRs recentes validados

| Repositório | PR | Status | Observação |
|---|---:|---:|---|
| CarrierService | #4 | OK | Mock repository atrás de `FeatureFlags:MockCarrierRepository`; default `false`, Development `true`; readiness de DB ignorada quando mock ativo. |
| ShipmentService | #4 | OK com ressalva | Mock repository atrás de `FeatureFlags:UseMockShipmentRepository`; default `false`, Development `true`; health check de DB ainda é registrado. |
| NotificationService | #4 | OK com ressalva | Mock repository atrás de `FeatureFlags:MockNotificationRepository`; default `false`, Development `true`; health check de DB ainda é registrado. |
| FulfillmentCenterService | #3 | OK com ressalva | Mock repositories atrás de `FeatureFlags:UseMockRepositories`; default `false`, Development `true`; health check de DB ainda é registrado. |
| TrackingService | #3 | OK com ressalva | Mock repository atrás de `FeatureFlags:MockTrackingRepository:Enabled`; default `false`, Development `true`; health check de DB ainda é registrado. |
| RoutingService | #3 | OK | `Routing:UseMockRepository`; default `false`, Development `true`; troca Redis por cache em memória e evita DB quando mock ativo. |
| CheckoutService | #4 | OK | Modo mock com `MockData:Enabled` ou ausência de connection string; preserva idempotência de checkout. |
| ProductCatalogService | #4 | Atenção | Serviço ficou sempre mockado em `Program.cs`, sem flag para alternar implementação real. Aceitável para local, não ideal como padrão definitivo. |
| ShippingPromiseService | #6 | OK | Build e testes reportados como executados com sucesso no PR; passa product physical info para candidate builder. |
| MarketplaceWeb.Bff | #15 | OK | Rotas/contratos de Tracking, Order, Shipment e cancelamento foram alinhados. |
| MarketplaceWeb.Bff | #12 | Pendente | PR aberto/draft, ajuste documental de URL local do Product Search. Não bloqueia runtime se configuração local estiver correta. |
| MarketplaceWeb | #10 | OK | Compatibilidade para `products` e `items` no response de busca e `SellerId` string; testes reportados como OK. |

## Validação por tema

### 1. Feature flags de mock

Padrão esperado:

- default/prod: mock desligado;
- development: mock ligado;
- DI troca interface por mock sem mudar contrato público.

Aderência:

- CarrierService: aderente.
- RoutingService: aderente.
- CheckoutService: aderente para local.
- ShipmentService: aderente, mas health check de DB pode falhar.
- NotificationService: aderente, mas health check de DB pode falhar.
- FulfillmentCenterService: aderente, mas health check de DB pode falhar.
- TrackingService: aderente, mas health check de DB pode falhar.
- ProductCatalogService: funcional para local, mas sem alternância por feature flag.

### 2. Contratos HTTP

Pontos revalidados:

- BFF chama `GET /tracking/shipments/{shipmentId}` no TrackingService.
- BFF removeu dependência de `GET /orders` inexistente.
- BFF envia body no cancelamento de pedido e trata `202 Accepted` sem body.
- BFF consome label do Shipment como JSON `{ url, expiresInSeconds }`.
- ShippingPromise envia `checkId` ao Carrier.
- ShippingPromise envia `buyerId`, `sellerId`, `destinationPostalCode`, `cartTotal`, `currency` e `candidates[]` ao Pricing.
- ShippingPromise lê `customerPrice` como preço ao cliente.

Status: **OK**.

### 3. Kafka e eventos

Não foram identificadas alterações recentes que quebrem os eventos documentados em `docs/contracts/kafka-events.md`.

Ponto de atenção: os mocks devem continuar evitando publicação real quando a intenção for execução local isolada, ou publicar apenas em outbox/logging publisher conforme o serviço.

### 4. Build/testes

Limitação da validação: não há status checks de CI nos commits consultados. Em vários PRs o próprio corpo informa que `dotnet build`/`dotnet test` não rodou porque o ambiente não tinha o CLI .NET disponível.

Exceções positivas:

- `ShippingPromiseService` PR #6 reporta `dotnet build` e `dotnet test` com sucesso.
- `MarketplaceWeb` PR #10 reporta `dotnet test` com sucesso.

## Recomendações

### Prioridade 1

Executar localmente, em cada repo alterado:

```bash
dotnet restore
dotnet build
dotnet test
```

### Prioridade 2

Ajustar health checks em serviços com mock repository:

- ShipmentService
- NotificationService
- FulfillmentCenterService
- TrackingService

Quando mock estiver ativo, o `/health` não deveria depender de banco real. Padrão recomendado: seguir o modelo do `CarrierService` e do `RoutingService`.

### Prioridade 3

Revisar `ProductCatalogService` para trocar mocks hardcoded por feature flag:

```json
{
  "FeatureFlags": {
    "UseMockRepositories": true
  }
}
```

Default `false`, Development `true`.

### Prioridade 4

Fechar ou descartar o PR draft `MarketplaceWeb.Bff#12`, para evitar ruído no board de PRs.

## Parecer final

Os PRs estão coerentes com o objetivo atual de facilitar execução local dos microservices e eliminar incompatibilidades entre BFF/ShippingPromise e downstreams.

Não encontrei bloqueio arquitetural crítico.

Antes de considerar a suíte estável, falta uma validação prática local com `docker compose`, `dotnet build`, `dotnet test` e smoke test dos endpoints principais.
