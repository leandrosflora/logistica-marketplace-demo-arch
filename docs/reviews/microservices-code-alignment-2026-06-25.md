# Review - Alinhamento da documentação com o código dos microservices

Data: **2026-06-25**

## Objetivo

Validar se o repositório `logistica-envios-demo-arch` reflete o que os microservices fazem na prática e ajustar somente documentação.

Nenhum código de microservice foi alterado.

## Escopo da varredura

Foram verificados os repositórios:

| Microservice | Status do repo |
|---|---|
| `CheckoutService` | Existe |
| `ProductSearchService` | Existe |
| `ShippingPromiseService` | Existe |
| `ProductCatalogService` | Existe |
| `InventoryService` | Existe |
| `FulfillmentCenterService` | Existe |
| `RoutingService` | Existe |
| `CarrierService` | Existe |
| `ShippingPricingService` | Existe |
| `OrderService` | Existe |
| `ShipmentService` | Existe |
| `TrackingService` | Existe |
| `NotificationService` | Existe |
| `PaymentService` | Não encontrado |
| `AuditService` | Não encontrado |

## Arquivos usados como fonte técnica

A análise priorizou:

- `Program.cs`;
- `Api/*Endpoints.cs`;
- `Infrastructure/Messaging/KafkaOptions.cs`;
- handlers centrais de saga, quando necessário.

## Principais achados

### 1. Payment Service não existe como microservice

A documentação tratava `PaymentService` como serviço implementado, com schema, APIs e eventos próprios.

Na prática:

- repo `leandrosflora/PaymentService` não existe;
- `OrderService` produz `payment.commands`;
- não há consumer real de `payment.commands` no conjunto atual;
- a etapa de pagamento é lacuna/simulação da saga.

Correção aplicada:

- removida spec `docs/services/payment-service.md`;
- `PaymentService` removido da matriz de microservices implementados;
- `payment.commands` mantido como tópico produzido sem consumidor implementado.

### 2. Audit Service não existe como microservice

A documentação tratava `AuditService` como consumidor de todos os eventos.

Na prática:

- repo `leandrosflora/AuditService` não existe;
- não há consumer de auditoria centralizado no conjunto atual.

Correção aplicada:

- removida spec `docs/services/audit-service.md`;
- removidas referências como consumer real em fluxos principais;
- auditoria centralizada documentada como não implementada.

### 3. Product Search usa Postgres, não OpenSearch no runtime atual

A documentação descrevia OpenSearch/Elasticsearch como implementação ativa.

Na prática:

- `Program.cs` registra `PostgresProductSearchRepository`;
- o repositório usa Dapper/Npgsql;
- a busca consulta tabela `products`;
- OpenSearch aparece como evolução/estrutura, mas não como implementação registrada.

Correção aplicada:

- `docs/services/product-search-service.md` atualizado;
- `README.md`, `services-map.md` e `data-stores.md` atualizados para Postgres read model.

### 4. Order Service cria pedido por Kafka, não por POST /v1/orders

A documentação citava `POST /v1/orders`.

Na prática:

- endpoints reais são `GET /orders/{orderId}` e `POST /orders/{orderId}/cancel`;
- criação ocorre por consumo de `checkout.confirmed`;
- `OrderService` escreve `order.created`, comandos internos e `order.events`.

Correção aplicada:

- `docs/services/order-service.md` atualizado;
- OpenAPI consolidado atualizado;
- Kafka documentado como parcial onde aplicável.

### 5. Shipment Service não publica shipment.cancelled no código atual

A documentação tratava `shipment.cancelled` como evento implementado.

Na prática:

- `KafkaOptions` do `ShipmentService` contém `order.created`, `shipment.created` e `shipment.commands`;
- cancelamento HTTP escreve `carrier-shipment.commands`;
- `shipment.cancelled` não aparece como tópico publicado implementado.

Correção aplicada:

- `docs/services/shipment-service.md` atualizado;
- `kafka-events.md` marca `shipment.cancelled` como tópico configurado/pendente, não E2E comprovado.

### 6. Notification Service consome tópicos que ainda não têm producer

Na prática, `NotificationService` configura consumo de:

- `order.created`;
- `order.confirmed`;
- `order.cancelled`;
- `payment.rejected`;
- `shipment.created`;
- `shipment.status.updated`;
- `shipment.cancelled`.

Mas nem todos têm producer implementado hoje.

Correção aplicada:

- `docs/services/notification-service.md` atualizado para separar producer real de tópico apenas configurado;
- `kafka-events.md` explicita tópicos configurados sem producer atual.

## Arquivos atualizados

| Arquivo | Tipo de ajuste |
|---|---|
| `README.md` | Visão geral alinhada aos 13 microservices reais e lacunas atuais |
| `docs/contracts/services-map.md` | Mapa de serviços refeito conforme código |
| `docs/contracts/data-stores.md` | Matriz de persistência/cache/Kafka corrigida |
| `docs/contracts/kafka-events.md` | Tópicos separados por implementado/parcial/pendente |
| `docs/contracts/logistica-envios-apis.openapi.yaml` | OpenAPI consolidado refeito com endpoints reais |
| `docs/c4/logistica-envios-container.puml` | Removidos Payment/Audit como containers implementados |
| `docs/runbooks/kafka-local-e2e.md` | Runbook ajustado para E2E parcial realista |
| `docs/services/product-search-service.md` | Corrigido para Postgres read model atual |
| `docs/services/order-service.md` | Corrigidos endpoints, eventos e lacuna de pagamento |
| `docs/services/shipment-service.md` | Corrigidos endpoints e eventos de cancelamento |
| `docs/services/notification-service.md` | Corrigidos eventos configurados versus implementados |
| `docs/services/payment-service.md` | Removido |
| `docs/services/audit-service.md` | Removido |

## Pontos que continuam como lacuna técnica

| Lacuna | Ação necessária para virar E2E completo |
|---|---|
| Pagamento | Implementar `PaymentService` ou adapter externo consumidor de `payment.commands`. |
| Auditoria centralizada | Implementar `AuditService` ou documentar outro mecanismo real de auditoria. |
| `order.confirmed` / `order.cancelled` canônicos | Alterar `OrderService` para publicar esses tópicos explicitamente, ou manter `order.events` como interno. |
| `shipment.cancelled` | Alterar `ShipmentService` para publicar evento canônico quando o cancelamento for confirmado. |
| Alguns consumers configurados sem producer | Implementar producers ou remover tópicos das configurações. |
| SVGs gerados | Regenerar SVGs a partir dos `.puml` pelo workflow de diagramas. |

## Conclusão

Antes da revisão, a documentação descrevia uma arquitetura-alvo maior do que a implementação real.

Depois da revisão, o repo de docs passa a refletir o estado prático dos microservices:

- 13 microservices implementados;
- `PaymentService` e `AuditService` removidos da visão implementada;
- Kafka marcado como parcial onde há lacunas reais;
- OpenAPI e specs individuais ajustados aos endpoints encontrados no código.
