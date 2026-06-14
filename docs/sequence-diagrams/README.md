# Sequence diagrams - Meli Envios

Esta pasta contém os diagramas de sequência da jornada de envios, cobrindo fluxo feliz e fluxos alternativos.

## Fluxos felizes

| Arquivo | Descrição |
|---|---|
| [`00-overview-shipping-journey-happy-path.puml`](00-overview-shipping-journey-happy-path.puml) | Visão macro da jornada completa: busca, cotação, checkout, pedido, reservas, shipment, tracking e notificação. |
| [`01-product-search-and-quote-happy-path.puml`](01-product-search-and-quote-happy-path.puml) | Busca de produto e cotação de frete com Product Search, Catalog, Shipping Promise e serviços logísticos. |
| [`02-checkout-confirmation-and-order-created.puml`](02-checkout-confirmation-and-order-created.puml) | Criação e confirmação de checkout, com emissão de evento para início da saga do pedido. |
| [`03-order-saga-reservations-and-shipment-happy-path.puml`](03-order-saga-reservations-and-shipment-happy-path.puml) | Saga do pedido, reserva de estoque, reserva de capacidade, confirmação e criação de shipment. |
| [`04-tracking-and-notification-happy-path.puml`](04-tracking-and-notification-happy-path.puml) | Atualização de tracking e notificação do comprador. |
| [`quote-shipping.puml`](quote-shipping.puml) | Diagrama original de cotação de frete e promessa de entrega. |

## Fluxos alternativos

| Arquivo | Descrição |
|---|---|
| [`10-alt-product-or-catalog-unavailable.puml`](10-alt-product-or-catalog-unavailable.puml) | Produto não encontrado, catálogo sem dados físicos ou busca sem resultado. |
| [`11-alt-inventory-unavailable.puml`](11-alt-inventory-unavailable.puml) | Estoque indisponível na cotação ou falha tardia de reserva. |
| [`12-alt-fulfillment-capacity-unavailable.puml`](12-alt-fulfillment-capacity-unavailable.puml) | Capacidade ou janela operacional indisponível no fulfillment. |
| [`13-alt-routing-carrier-pricing-unavailable.puml`](13-alt-routing-carrier-pricing-unavailable.puml) | Ausência de rota, carrier indisponível ou falha de precificação. |
| [`14-alt-payment-failed-compensation.puml`](14-alt-payment-failed-compensation.puml) | Falha de autorização e compensações de estoque/capacidade. |
| [`15-alt-shipment-failed-compensation.puml`](15-alt-shipment-failed-compensation.puml) | Falha na criação do shipment e compensações da saga. |
| [`16-alt-delivery-exception-and-notification.puml`](16-alt-delivery-exception-and-notification.puml) | Exceção de entrega, atualização de tracking e notificação. |
| [`17-alt-cancel-order-before-shipment.puml`](17-alt-cancel-order-before-shipment.puml) | Cancelamento do pedido antes da criação do shipment. |

## Renderização

Os arquivos `.puml` são renderizados para `.svg` pelo workflow:

```text
.github/workflows/render-diagrams.yml
```

Também é possível renderizar localmente:

```bash
docker run --rm -v "$PWD:/work" plantuml/plantuml:latest -tsvg /work/docs/sequence-diagrams/*.puml
```
