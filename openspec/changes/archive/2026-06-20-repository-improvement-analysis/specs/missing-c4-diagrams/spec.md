## ADDED Requirements

### Requirement: Diagramas C4 nível 3 criados para domínios sem cobertura
O repositório SHALL conter diagramas C4 nível 3 (Component) em formato PlantUML para os domínios que ainda não possuem diagrama: Checkout, ShippingPromise, Pricing/Carrier/Routing (agrupados como "cotação"), e Inventory/Fulfillment.

#### Scenario: Arquivo .puml criado para domínio Checkout
- **WHEN** o diretório `docs/c4/` é listado
- **THEN** ele MUST conter o arquivo `meli-envios-checkout-domain-level3.puml` com componentes internos do `CheckoutService` (Controller, Application Service, Domain, Infrastructure, Kafka Producer, Kafka Consumer)

#### Scenario: Arquivo .puml criado para domínio ShippingPromise
- **WHEN** o diretório `docs/c4/` é listado
- **THEN** ele MUST conter o arquivo `meli-envios-shipping-promise-domain-level3.puml` com componentes do `ShippingPromiseService` e suas dependências síncronas (ProductCatalog, Inventory, FulfillmentCenter, Routing, Carrier, Pricing)

#### Scenario: Arquivo .puml criado para domínio Order/Saga
- **WHEN** o diretório `docs/c4/` é listado
- **THEN** ele MUST conter o arquivo `meli-envios-order-saga-level3.puml` mostrando o fluxo da saga com o `OrderProcessManager` e os tópicos internos de saga

#### Scenario: SVG atualizado para novos diagramas
- **WHEN** o comando PlantUML Docker é executado (`docker run --rm -v "$PWD:/work" plantuml/plantuml -tsvg /work/docs/c4/*.puml`)
- **THEN** arquivos `.svg` correspondentes DEVEM ser gerados para cada novo `.puml`

### Requirement: Diagramas existentes mantêm consistência com contratos atualizados
Os diagramas C4 nível 3 existentes (Order, Shipment, Tracking) SHALL ser revisados para garantir alinhamento com os contratos Kafka canônicos atuais.

#### Scenario: Diagrama de Shipment reflete sellerId
- **WHEN** o arquivo `meli-envios-shipment-domain-level3.puml` é lido
- **THEN** a relação de publicação do tópico `shipment.created` MUST mencionar que o payload inclui `sellerId` (após a atualização do contrato)
