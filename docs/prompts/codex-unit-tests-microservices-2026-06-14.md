# Prompt Codex — Testes unitários dos microservices Meli Envios

Use este repositório como fonte de contexto arquitetural.

Objetivo: criar uma suíte mínima, consistente e executável de testes unitários para cada microservice do case **Meli Envios**, sem alterar contratos públicos sem necessidade.

## Contexto obrigatório

Antes de modificar código, leia:

- `README.md`
- `AGENTS.md`
- `docs/contracts/services-map.md`
- `docs/contracts/kafka-events.md`
- `docs/contracts/meli-envios-apis.openapi.yaml`
- `docs/adr/*.md`

O repositório `meli-envios-architecture` não contém o código-fonte dos microservices. Ele contém o mapa arquitetural, contratos, eventos Kafka, ADRs e comandos esperados de validação. Os testes devem ser criados nos repositórios dos microservices listados no README.

## Microservices no escopo

Criar testes unitários para:

1. `CheckoutService`
2. `ProductSearchService`
3. `ShippingPromiseService`
4. `ProductCatalogService`
5. `InventoryService`
6. `FulfillmentCenterService`
7. `RoutingService`
8. `CarrierService`
9. `ShippingPricingService`
10. `OrderService`
11. `ShipmentService`
12. `TrackingService`
13. `NotificationService`

Não incluir `MarketplaceWeb` nem `MarketplaceWeb.Bff` nesta rodada, salvo se a tarefa for explicitamente ampliada.

## Padrão de projeto de teste

Para cada repositório de microservice:

1. Criar projeto:

```bash
dotnet new xunit -n <ServiceName>.UnitTests
```

2. Adicionar referência ao projeto principal:

```bash
dotnet add <ServiceName>.UnitTests/<ServiceName>.UnitTests.csproj reference <ServiceName>.csproj
```

3. Adicionar ao `.sln`:

```bash
dotnet sln add <ServiceName>.UnitTests/<ServiceName>.UnitTests.csproj
```

4. Usar pacotes:

```bash
dotnet add <ServiceName>.UnitTests package FluentAssertions
dotnet add <ServiceName>.UnitTests package NSubstitute
```

Preferência: `xUnit + FluentAssertions + NSubstitute`.

Não usar dependências reais de Kafka, PostgreSQL, HTTP externo ou Docker em teste unitário.

## Critérios de design dos testes

Separar testes em três camadas, quando existirem classes correspondentes:

```text
<ServiceName>.UnitTests/
├── Application/
├── Domain/
├── Contracts/
└── TestDoubles/
```

### Application

Testar casos de uso e services de aplicação:

- validação de entrada obrigatória;
- idempotência quando houver chave idempotente;
- chamada correta de portas/interfaces;
- publicação correta de eventos no outbox ou publisher fake;
- tratamento de dependência indisponível;
- retorno esperado para caminho feliz;
- erro esperado para regra de negócio inválida.

### Domain

Testar entidades, value objects e regras puras:

- criação válida;
- rejeição de estado inválido;
- transições de status;
- cálculo de totais, prazos, custos ou disponibilidade;
- invariantes do agregado.

### Contracts

Testar apenas mapeamentos puros, DTOs e envelopes quando houver lógica ou fábrica:

- tópico Kafka correto;
- `eventType` correto;
- `schemaVersion` correto;
- presença de `correlationId`;
- payload coerente com contrato documentado.

## Foco por microservice

### CheckoutService

Cobrir:

- criação de checkout com request válido;
- rejeição de checkout sem buyer, seller, itens ou CEP;
- reaproveitamento de checkout por idempotency key;
- exceção quando shipping promise retornar indisponível;
- publicação de `checkout.shipping.quote.requested`;
- confirmação de checkout;
- erro ao confirmar checkout inexistente.

### ProductSearchService

Cobrir:

- busca textual retorna produtos compatíveis;
- texto vazio ou inválido retorna erro ou lista vazia, conforme comportamento atual;
- filtro preserva somente produtos ofertados;
- paginação/limite, se existir;
- ordenação por relevância, se existir.

### ShippingPromiseService

Cobrir:

- cálculo de promessa disponível;
- indisponibilidade quando catálogo, estoque, fulfillment, routing ou carrier negarem condição;
- cálculo usando prazo, modalidade, transportadora e custo;
- fallback quando dependência estiver indisponível, se existir;
- publicação de `shipping.promise.calculated`;
- respeito a `correlationId`.

### ProductCatalogService

Cobrir:

- retorno de peso, dimensão, categoria e restrições por SKU;
- erro/not found para SKU inexistente;
- validação de SKU obrigatório;
- restrições logísticas por categoria, se houver.

### InventoryService

Cobrir:

- consulta de estoque por SKU, seller e fulfillment center;
- disponibilidade suficiente;
- indisponibilidade por quantidade insuficiente;
- SKU/seller inválido;
- reserva/liberação, se houver comando implementado.

### FulfillmentCenterService

Cobrir:

- retorno de capacidade e cutoff;
- indisponibilidade por capacidade esgotada;
- indisponibilidade por janela/cutoff vencido;
- seleção de fulfillment center elegível;
- validação de região/CEP, se existir.

### RoutingService

Cobrir:

- cálculo de rota válida;
- ausência de rota disponível;
- seleção por menor prazo/custo, conforme regra atual;
- validação de origem/destino;
- hubs e janelas logísticas, se implementados.

### CarrierService

Cobrir:

- transportadora disponível para rota/modalidade;
- restrição por peso, dimensão ou região;
- indisponibilidade de carrier;
- seleção de carrier elegível;
- cálculo/retorno de SLA, se existir.

### ShippingPricingService

Cobrir:

- cálculo de frete básico;
- aplicação de subsídio/promoção, se existir;
- rejeição de peso/dimensão/custo inválido;
- cálculo por modalidade/região;
- arredondamento monetário consistente.

### OrderService

Cobrir:

- criação de pedido com checkout confirmado;
- idempotência de criação;
- publicação de `order.created`;
- publicação/uso dos tópicos internos de saga, se implementados:
  - `inventory.commands`
  - `fulfillment.commands`
  - `payment.commands`
  - `shipment.commands`
  - `order.events`
- transições de status do pedido;
- erro para comando inválido.

### ShipmentService

Cobrir:

- criação de shipment a partir de `order.created`;
- idempotência por order/shipment key;
- publicação de `shipment.created`;
- geração de etiqueta/pacote/volume, se houver regra pura;
- erro para pedido inválido.

### TrackingService

Cobrir:

- atualização de status de entrega;
- rejeição de transição inválida;
- publicação de `shipment.status.updated`;
- manutenção de histórico de eventos;
- idempotência de evento repetido.

### NotificationService

Cobrir:

- decisão de notificar buyer/seller para eventos relevantes;
- não notificar evento irrelevante;
- montagem de mensagem sem chamar provider real;
- deduplicação/idempotência de notificação;
- tratamento de falha do provider por fake/mock.

## Regras obrigatórias

- Não criar teste de integração disfarçado de unitário.
- Não subir Docker.
- Não depender de Kafka real.
- Não depender de banco real.
- Não alterar contratos REST/Kafka só para facilitar teste.
- Não alterar nomes de tópicos Kafka documentados.
- Não usar sleeps, delays ou dependência de relógio real; se necessário, introduzir abstração simples de clock.
- Preferir testar regra de negócio em classe pura antes de testar endpoint.
- Endpoint minimal API só deve ser testado se a lógica estiver no endpoint; se a regra estiver no service, testar o service.

## Ajustes permitidos para testabilidade

Pode fazer refactors pequenos e seguros:

- extrair interfaces para dependências externas;
- tornar classes `public` quando forem parte da camada de aplicação/domínio e precisarem ser testadas;
- extrair factories de evento;
- extrair clock para interface;
- mover lógica de endpoint para application service.

Não fazer refactor estrutural grande nesta tarefa.

## Validação obrigatória por repositório

Executar, para cada microservice:

```bash
dotnet restore
dotnet build
dotnet test
```

Se houver `dotnet format` configurado:

```bash
dotnet format --verify-no-changes
```

## Resultado esperado

Para cada microservice, entregar:

- projeto `<ServiceName>.UnitTests` criado;
- `.sln` atualizado;
- testes cobrindo pelo menos 3 caminhos:
  - caminho feliz;
  - validação/erro;
  - idempotência, evento ou chamada de dependência;
- nenhum teste dependente de infraestrutura real;
- `dotnet test` passando.

## Estratégia de commit

Preferir commits separados por microservice:

```text
test(checkout): add unit tests
test(product-search): add unit tests
test(shipping-promise): add unit tests
test(product-catalog): add unit tests
test(inventory): add unit tests
test(fulfillment-center): add unit tests
test(routing): add unit tests
test(carrier): add unit tests
test(shipping-pricing): add unit tests
test(order): add unit tests
test(shipment): add unit tests
test(tracking): add unit tests
test(notification): add unit tests
```

## Saída esperada do Codex

Ao final, informar:

- lista de repositórios alterados;
- quantidade de testes criados por microservice;
- principais cenários cobertos;
- comandos executados;
- erros encontrados e correções feitas;
- pendências, se algum repo não compilar por problema pré-existente.
