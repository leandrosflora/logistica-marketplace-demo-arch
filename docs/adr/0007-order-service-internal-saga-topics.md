# ADR-0007 — Tópicos internos de saga do OrderService

## Status

Aceita

## Data

2026-06-14

## Revisão de alinhamento

Revisada em **2026-06-25** para refletir a implementação atual dos microservices.

## Contexto

O `OrderService` participa da orquestração da saga de criação de pedido.

Durante esse fluxo, ele publica mensagens Kafka em tópicos usados para coordenar ações com serviços dependentes:

- `inventory.commands`
- `fulfillment.commands`
- `payment.commands`
- `shipment.commands`
- `order.events`

Esses tópicos não fazem parte da lista de eventos canônicos públicos. São tópicos internos/controlados da saga.

A revisão de 2026-06-25 identificou que:

- `inventory.commands` possui consumer implementado no `InventoryService`;
- `fulfillment.commands` possui consumer implementado no `FulfillmentCenterService`;
- `shipment.commands` possui consumer implementado no `ShipmentService`;
- `payment.commands` é produzido pelo `OrderService`, mas não possui consumer implementado porque `PaymentService` não existe no conjunto atual;
- `order.events` é usado como tópico interno/controlado para eventos do contexto de pedidos.

## Decisão

Os tópicos serão documentados como **tópicos internos de saga do OrderService**.

Eles não serão tratados como eventos canônicos públicos neste momento.

A nomenclatura atual será mantida para representar comandos internos de orquestração:

- `inventory.commands`
- `fulfillment.commands`
- `payment.commands`
- `shipment.commands`

O tópico `order.events` será documentado como tópico interno de eventos do contexto de pedidos, usado pela saga e por consumidores controlados.

## Eventos canônicos futuros ou parciais

Eventos públicos de domínio podem existir como evolução, desde que tenham producer real, contrato versionado e owner explícito.

Exemplos de eventos canônicos válidos quando implementados:

- `order.created` — implementado;
- `shipment.created` — implementado;
- `shipment.status.updated` — implementado;
- `order.confirmed` — não publicado canonicamente pelo `OrderService` atual;
- `order.cancelled` — não publicado canonicamente pelo `OrderService` atual;
- `payment.approved` / `payment.rejected` — dependem de `PaymentService` ou adapter externo ainda ausente;
- `shipment.cancelled` — não publicado pelo `ShipmentService` atual.

## Justificativa

Comandos internos de saga e eventos canônicos de domínio têm objetivos diferentes.

Comandos internos representam intenção de execução dentro de um fluxo orquestrado. Exemplos:

- reservar estoque;
- iniciar autorização/captura de pagamento;
- acionar criação de entrega;
- validar capacidade de fulfillment.

Eventos canônicos representam fatos de negócio já ocorridos, com contrato estável e potencial consumo por múltiplos domínios. Exemplos:

- pedido criado;
- entrega criada;
- status de entrega atualizado;
- pedido cancelado, quando houver producer canônico.

Migrar os tópicos internos para nomes canônicos agora poderia misturar comandos de implementação da saga com eventos públicos de domínio, aumentando acoplamento indevido entre serviços.

## Consequências positivas

- Mantém compatibilidade com a implementação atual do `OrderService`.
- Deixa explícita a separação entre comando interno e evento canônico.
- Evita consumo indevido de tópicos internos por outros domínios.
- Reduz acoplamento entre serviços.
- Permite evolução futura para tópicos canônicos mediante decisão explícita.

## Consequências negativas

- A arquitetura passa a ter dois níveis de contrato Kafka: internos e canônicos.
- O `kafka-events.md` precisa deixar clara a diferença entre tópicos internos e eventos públicos.
- Consumidores precisam respeitar a regra de não consumir tópicos internos sem aprovação arquitetural.
- `payment.commands` fica como lacuna enquanto não existir consumer real.

## Regra arquitetural

Tópicos terminados em `.commands` representam comandos internos de orquestração.

Eles não devem ser consumidos livremente por outros domínios e não devem ser tratados como eventos canônicos.

Eventos canônicos devem representar fatos de negócio já ocorridos, ter contrato versionado, ownership claro, semântica estável e producer real.

## Critério de promoção para tópico canônico

Um tópico interno só deve ser promovido para tópico canônico quando:

1. for consumido por múltiplos domínios independentes;
2. representar um fato de negócio estável;
3. tiver contrato versionado;
4. tiver owner definido;
5. tiver producer real implementado;
6. for aprovado por nova ADR.

## Decisão final

Manter os tópicos atuais como internos de saga e documentá-los no `docs/contracts/kafka-events.md` com status prático de implementação.
