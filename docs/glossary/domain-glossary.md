# Glossário de Domínio — Logística Envios

Definições formais dos termos usados no ecossistema Logística Envios. Todos os agentes de IA e desenvolvedores devem consultar este glossário para garantir linguagem ubíqua consistente em código, contratos e documentação.

---

## A–C

### Buyer
**Definição:** Usuário que realiza a compra no marketplace. Identificado por `buyerId` (UUID).
**Contexto de uso:** Presente em todos os eventos e contratos que envolvem a jornada de compra (`checkout.shipping.quote.requested`, `order.created`, `shipment.created`, `shipment.status.updated`).
**Termos relacionados:** Seller, Order, Checkout

### Carrier
**Definição:** Transportadora responsável pela movimentação física do pacote do fulfillment center até o destino do buyer. Exemplos: Correios, transportadoras privadas, parceiros last-mile.
**Contexto de uso:** `Carrier Service`, campo `carrierCode` em contratos Kafka e OpenAPI.
**Termos relacionados:** Carrier Service, Route, Service Level, Shipment

### Carrier Service (microservice)
**Definição:** Microservice responsável por integrar com transportadoras, consultar restrições, modalidades disponíveis e opções de entrega para uma rota e pacote específicos.
**Contexto de uso:** Dependência síncrona do `Shipping Promise Service`.
**Termos relacionados:** Carrier, Route, Shipping Promise Service

### Checkout
**Definição:** Processo transacional iniciado quando o buyer decide confirmar a compra de um ou mais itens do carrinho. Inclui cotação de frete, seleção de modalidade, pagamento e confirmação.
**Contexto de uso:** `Checkout Service`, evento `checkout.shipping.quote.requested`, campo `checkoutId`.
**Termos relacionados:** Checkout Service, Shipping Promise, Order

### Checkout Service (microservice)
**Definição:** Microservice que orquestra a experiência de compra do ponto de vista do usuário. Coordena cotação de frete, confirmação de pagamento e criação de pedido.
**Contexto de uso:** Producer do evento `checkout.shipping.quote.requested`; consumer de `shipping.promise.calculated`.
**Termos relacionados:** Checkout, BFF, Order Service

### Consumer Group
**Definição:** Identificador de grupo de consumers Kafka. Mensagens de uma partição são processadas por apenas um consumer do grupo, garantindo paralelismo controlado.
**Contexto de uso:** Cada microservice tem seu `ConsumerGroupId` configurado (ex: `shipment-service`).
**Termos relacionados:** Kafka, Tópico Canônico, Tópico Interno

### CorrelationId
**Definição:** UUID propagado em todos os saltos de uma requisição (HTTP headers e envelope Kafka) para rastrear uma jornada de ponta a ponta nos logs e traces.
**Contexto de uso:** Header `x-correlation-id` em APIs; campo `correlationId` no envelope Kafka; atributo OTEL `correlation.id`.
**Termos relacionados:** x-correlation-id, TraceId, Envelope Kafka

### Corridor
**Definição:** Par origem-destino de uma rota logística (ex: SP → RJ), representando o corredor de distribuição utilizado para calcular prazo e custo.
**Contexto de uso:** `Routing Service`, cálculo de rotas e SLA.
**Termos relacionados:** Route, Hub, Malha Logística

### Cutoff
**Definição:** Horário limite para que um pedido seja aceito e processado com entrega na data prometida. Pedidos recebidos após o cutoff têm entrega prometida para o próximo dia útil.
**Contexto de uso:** `Fulfillment Center Service`, cálculo de `estimatedDeliveryDate` em `Shipping Promise Service`.
**Termos relacionados:** Fulfillment Center, SLA, Same Day

---

## D–G

### Delivery Exception
**Definição:** Evento de rastreio que indica uma falha ou desvio no processo de entrega (ex: destinatário ausente, endereço incorreto, dano ao pacote).
**Contexto de uso:** `Tracking Service`, campo `exceptionCode` em `shipment.status.updated`.
**Termos relacionados:** Tracking Event, Shipment, Notification Service

---

## E–H

### Envelope Kafka
**Definição:** Estrutura obrigatória que envolve o `payload` de todo evento Kafka canônico, contendo campos de metadados: `eventId`, `eventType`, `schemaVersion`, `occurredAt`, `correlationId`, `producer`, `payload`.
**Contexto de uso:** Todos os tópicos canônicos em `docs/contracts/kafka-events.md`.
**Termos relacionados:** Tópico Canônico, CorrelationId, SchemaVersion

### EstimatedDeliveryDate
**Definição:** Data estimada de entrega ao buyer, calculada com base em SLA, cutoff, rota logística e modalidade de envio.
**Contexto de uso:** Campos `estimatedDeliveryDate` e `promisedDeliveryDate` em contratos Kafka e OpenAPI.
**Termos relacionados:** Shipping Promise, SLA, Cutoff

### EventId
**Definição:** UUID globalmente único que identifica uma instância específica de um evento Kafka. Usado para deduplicação no Inbox Pattern.
**Contexto de uso:** Campo `eventId` no envelope Kafka; chave de idempotência na tabela `inbox_messages`.
**Termos relacionados:** Envelope Kafka, Inbox Pattern, Idempotência

### Fulfillment Center (CD — Centro de Distribuição)
**Definição:** Instalação logística onde produtos são armazenados, separados e expedidos para entrega. Também chamado de CD (Centro de Distribuição).
**Contexto de uso:** `Fulfillment Center Service`, campo `originNodeId` em `order.created`.
**Termos relacionados:** Fulfillment Center Service, Inventory Service, Cutoff

### Fulfillment Center Service (microservice)
**Definição:** Microservice que gerencia capacidade operacional, horários de cutoff e disponibilidade dos centros de distribuição.
**Contexto de uso:** Dependência síncrona do `Shipping Promise Service`.
**Termos relacionados:** Fulfillment Center, Cutoff, Shipping Promise Service

---

## H–L

### Hub
**Definição:** Ponto intermediário na malha logística onde pacotes são consolidados ou redistribuídos entre rotas.
**Contexto de uso:** `Routing Service`, cálculo de malha e SLA de rota.
**Termos relacionados:** Malha Logística, Corridor, Route

### Inbox Pattern
**Definição:** Padrão de idempotência para consumers Kafka: o `eventId` da mensagem é registrado em tabela `inbox_messages` antes do processamento; mensagens duplicadas (mesmo `eventId`) são descartadas.
**Contexto de uso:** Obrigatório em todos os consumers Kafka críticos. Especificado em [ADR-0005](../adr/0005-idempotency-strategy.md).
**Termos relacionados:** Idempotência, EventId, Outbox Pattern

---

## L–O

### Label (Etiqueta)
**Definição:** Documento gerado para identificação e rastreio físico do pacote junto à transportadora. Contém código de barras ou QR code do `trackingCode`.
**Contexto de uso:** `Shipment Service`, campo `labelObjectKey` em `shipment.created`.
**Termos relacionados:** Shipment Service, Tracking Code, Carrier

### Malha Logística
**Definição:** Rede de rotas, corredores, hubs e transportadoras disponíveis para movimentação de pacotes entre origens e destinos.
**Contexto de uso:** `Routing Service`, cálculo de rotas e SLAs.
**Termos relacionados:** Route, Hub, Corridor, Carrier

---

## N–O

### Next Day
**Definição:** Modalidade de entrega com promessa de entrega no próximo dia útil após a expedição.
**Contexto de uso:** Campo `mode` ou `serviceLevelCode` em contratos de promessa e shipment.
**Termos relacionados:** Same Day, Standard, Service Level, SLA

---

## O–Q

### Order (Pedido)
**Definição:** Entidade de negócio criada após a confirmação do checkout pelo buyer. Representa a intenção de compra confirmada, com dados de pagamento, itens e promessa de entrega.
**Contexto de uso:** `Order Service`, evento `order.created`, campo `orderId`.
**Termos relacionados:** Order Service, Checkout, Shipment

### Order Service (microservice)
**Definição:** Microservice que cria e mantém o pedido após confirmação da compra. Orquestra a saga de criação de pedido via `OrderProcessManager`.
**Contexto de uso:** Producer de `order.created`, `order.confirmed`, `order.cancelled`; consumer de `shipment.status.updated`.
**Termos relacionados:** Saga Orchestrator, OrderProcessManager, Shipment Service

### Outbox Pattern
**Definição:** Padrão de publicação confiável para Kafka: o evento é gravado na tabela `outbox_messages` na mesma transação de banco que a operação de negócio. Um `OutboxDispatcher` assíncrono lê e publica no Kafka.
**Contexto de uso:** Obrigatório para producers de eventos de domínio críticos. Especificado em [ADR-0005](../adr/0005-idempotency-strategy.md).
**Termos relacionados:** Idempotência, Inbox Pattern, EventId

---

## P–R

### Package (Pacote)
**Definição:** Unidade física de envio contendo um ou mais itens de um pedido. Possui dimensões (peso, altura, largura, comprimento) que impactam o cálculo de frete.
**Contexto de uso:** Campo `packages[]` em `order.created`; base para cálculo em `Shipping Pricing Service`.
**Termos relacionados:** Shipment, Label, Shipping Pricing Service

### Promise Id
**Definição:** Identificador único da promessa de entrega calculada pelo `Shipping Promise Service` para um checkout específico.
**Contexto de uso:** Campo `promiseId` em `shipping.promise.calculated`; `shippingPromiseId` em `order.created`.
**Termos relacionados:** Shipping Promise, Checkout, EstimatedDeliveryDate

### Route
**Definição:** Caminho logístico calculado entre a origem (fulfillment center) e o destino (endereço do buyer), incluindo malha, hubs e transportadoras.
**Contexto de uso:** `Routing Service`, campo `routeId` em `order.created`.
**Termos relacionados:** Routing Service, Malha Logística, Corridor

### Routing Service (microservice)
**Definição:** Microservice que calcula rotas logísticas, malha, hubs e janelas de entrega para uma origem e destino.
**Contexto de uso:** Dependência síncrona do `Shipping Promise Service`.
**Termos relacionados:** Route, Malha Logística, Hub

---

## S

### Same Day
**Definição:** Modalidade de entrega com promessa de entrega no mesmo dia da compra, sujeita ao horário de cutoff do fulfillment center.
**Contexto de uso:** Campo `mode` ou `serviceLevelCode` com valor `same_day` em contratos.
**Termos relacionados:** Next Day, Standard, Cutoff, Service Level

### SchemaVersion
**Definição:** Versão do schema do payload de um evento Kafka, no formato `<major>.<minor>` (ex: `"1.0"`, `"1.1"`). Governado pelo [ADR-0004](../adr/0004-kafka-schema-versioning.md).
**Contexto de uso:** Campo `schemaVersion` no envelope Kafka de todos os eventos canônicos.
**Termos relacionados:** Envelope Kafka, Versionamento de Schema

### Seller
**Definição:** Vendedor que oferta produtos no marketplace. Identificado por `sellerId` (UUID).
**Contexto de uso:** Presente em contratos de checkout, cotação e pedido; recebe notificações sobre status de entrega via `Notification Service`.
**Termos relacionados:** Buyer, Order, Shipment

### Service Level
**Definição:** Nível de serviço contratado para a entrega (ex: `same_day`, `next_day`, `standard`). Determina o prazo prometido e o custo de frete.
**Contexto de uso:** Campos `serviceLevelCode` e `mode` em contratos Kafka e OpenAPI.
**Termos relacionados:** SLA, Carrier, Route

### Shipment (Entrega)
**Definição:** Entidade que representa a entrega física de um pedido: etiqueta, volume, código de rastreio e estado de entrega. Criada pelo `Shipment Service` após receber `order.created`.
**Contexto de uso:** `Shipment Service`, evento `shipment.created`, campo `shipmentId`.
**Termos relacionados:** Shipment Service, Label, Tracking Code

### Shipment Service (microservice)
**Definição:** Microservice responsável por criar a entrega física, gerar etiqueta, definir volume e gerenciar o ciclo de vida do shipment.
**Contexto de uso:** Consumer de `order.created`; producer de `shipment.created`.
**Termos relacionados:** Shipment, Label, Tracking Service

### Shipping Promise
**Definição:** Resultado do cálculo de prazo, disponibilidade, modalidade de envio e custo de frete para um conjunto de itens e destino. Inclui `estimatedDeliveryDate`, `mode`, `carrier` e `cost`.
**Contexto de uso:** `Shipping Promise Service`, evento `shipping.promise.calculated`.
**Termos relacionados:** Shipping Promise Service, EstimatedDeliveryDate, Service Level

### Shipping Promise Service (microservice)
**Definição:** Microservice central do fluxo de cotação. Recebe dados de itens e destino, consulta dependências síncronas e retorna a promessa de entrega.
**Contexto de uso:** Consumer de `checkout.shipping.quote.requested`; producer de `shipping.promise.calculated`. Dependências: ProductCatalog, Inventory, FulfillmentCenter, Routing, Carrier, Pricing.
**Termos relacionados:** Shipping Promise, Checkout Service, Product Catalog Service

### SKU (Stock Keeping Unit)
**Definição:** Unidade de manutenção de estoque. Identificador único de uma variação de produto (combinação de produto, cor, tamanho, etc.).
**Contexto de uso:** Campo `skuId` em contratos de cotação, estoque e catalogo de produtos.
**Termos relacionados:** Product Catalog Service, Inventory Service, Package

### SLA (Service Level Agreement)
**Definição:** Acordo de nível de serviço que define o prazo máximo de entrega para uma rota e modalidade. Exemplo: "Same Day = entrega até 23:59 do dia da compra feita antes das 14h".
**Contexto de uso:** Calculado pelo `Routing Service` e `Shipping Promise Service`.
**Termos relacionados:** SLO, Service Level, EstimatedDeliveryDate

### SLO (Service Level Objective)
**Definição:** Objetivo interno de nível de serviço para um microservice. Exemplo: "99.9% de disponibilidade" ou "P99 de latência < 200ms".
**Contexto de uso:** Documentado em `docs/services/<nome>-service.md` para cada microservice.
**Termos relacionados:** SLA, Observabilidade

### Standard
**Definição:** Modalidade de entrega padrão com prazo de 3 a 7 dias úteis, menor custo de frete.
**Contexto de uso:** Campo `mode` ou `serviceLevelCode` com valor `standard` em contratos.
**Termos relacionados:** Same Day, Next Day, Service Level

### Subsídio de Frete
**Definição:** Desconto aplicado pelo marketplace ou seller no custo de frete, reduzindo o valor cobrado ao buyer.
**Contexto de uso:** `Shipping Pricing Service`, cálculo de custo final de frete.
**Termos relacionados:** Shipping Pricing Service, Cost, Service Level

---

## T

### Tópico Canônico
**Definição:** Tópico Kafka que representa um evento de negócio público, com contrato estável, `schemaVersion` e owner definido. Documentado em `docs/contracts/kafka-events.md`.
**Contexto de uso:** Tópicos como `order.created`, `shipment.created`, `shipment.status.updated`.
**Termos relacionados:** Tópico Interno, Envelope Kafka, SchemaVersion

### Tópico Interno (Saga)
**Definição:** Tópico Kafka usado internamente pelo `OrderService` para orquestração da saga de criação de pedido. Não deve ser consumido por outros domínios sem decisão arquitetural. Documentado em [ADR-0007](../adr/0007-order-service-internal-saga-topics.md).
**Contexto de uso:** `inventory.commands`, `fulfillment.commands`, `payment.commands`, `shipment.commands`, `order.events`.
**Termos relacionados:** Tópico Canônico, Saga Orchestrator, Order Service

### Tracking Code
**Definição:** Código alfanumérico único que identifica um shipment junto à transportadora para rastreio físico do pacote. Exemplo: `BR123456789`.
**Contexto de uso:** Campo `trackingCode` em `shipment.created` e `shipment.status.updated`.
**Termos relacionados:** Tracking Service, Shipment, Carrier

### Tracking Event
**Definição:** Atualização de status de um shipment gerada pela transportadora ou pelo `Tracking Service`. Exemplos: `in_transit`, `out_for_delivery`, `delivered`, `delivery_failed`.
**Contexto de uso:** `Tracking Service`, campo `currentStatus` em `shipment.status.updated`.
**Termos relacionados:** Tracking Service, Shipment, Delivery Exception

### Tracking Service (microservice)
**Definição:** Microservice responsável por receber atualizações de status de entrega (da transportadora ou eventos internos), manter a linha do tempo e publicar `shipment.status.updated`.
**Contexto de uso:** Consumer de `shipment.created`; producer de `shipment.status.updated`.
**Termos relacionados:** Tracking Code, Tracking Event, Notification Service
