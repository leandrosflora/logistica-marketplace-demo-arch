# Mapa de Microservices

## Visão geral

| Serviço | Tipo | Dono do dado | Entrada principal | Saída principal |
|---|---|---|---|---|
| Product Search Service | Negócio | Índice de produtos ofertados | texto livre, filtros | produtos ofertados |
| Checkout Service | Jornada | carrinho/transação em andamento | carrinho | cotação e intenção de compra |
| Shipping Promise Service | Domínio logístico | promessa de entrega | SKU, destino, seller, quantidade | prazo, modalidade, disponibilidade |
| Product Catalog Service | Domínio catálogo | atributos logísticos do produto | SKU | peso, dimensão, restrições |
| Inventory Service | Domínio estoque | saldo e reserva | SKU, seller, FC | disponibilidade |
| Fulfillment Center Service | Domínio fulfillment | capacidade operacional | FC, janela, cutoff | disponibilidade operacional |
| Routing Service | Domínio roteirização | rotas e malha | origem, destino, modalidade | rota e SLA |
| Carrier Service | Integração | transportadoras e restrições | rota, CEP, pacote | opções de carrier |
| Shipping Pricing Service | Domínio precificação | custo, frete, subsídio | rota, carrier, pacote | preço de frete |
| Order Service | Domínio pedido | pedido confirmado | checkout confirmado | pedido |
| Shipment Service | Domínio entrega | shipment, volume, etiqueta | order created | shipment |
| Tracking Service | Domínio tracking | status de entrega | eventos de carrier/shipment | linha do tempo |
| Notification Service | Plataforma | notificações | eventos de domínio | mensagens ao cliente |
| Audit Service | Plataforma | trilhas de auditoria | eventos técnicos e funcionais | auditoria consultável |

## Fluxo síncrono de cotação

1. Frontend chama BFF.
2. BFF chama Product Search Service quando o usuário pesquisa produtos.
3. BFF/Checkout chama Shipping Promise Service para cotação.
4. Shipping Promise Service consulta:
   - Product Catalog Service;
   - Inventory Service;
   - Fulfillment Center Service;
   - Routing Service;
   - Carrier Service;
   - Shipping Pricing Service.
5. Resultado volta com modalidades, prazo, preço e disponibilidade.

## Fluxo assíncrono de pedido

1. Order Service publica `order.created`.
2. Shipment Service consome e cria shipment.
3. Shipment Service publica `shipment.created`.
4. Tracking Service acompanha eventos de atualização.
5. Notification Service notifica comprador/seller.
6. Audit Service persiste rastreabilidade.
