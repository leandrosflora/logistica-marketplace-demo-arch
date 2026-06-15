# ADR-0001 — Tópicos internos de saga do OrderService

## Status

Aceita

## Data

2026-06-14

## Contexto

O `OrderService` participa da orquestração da saga de criação de pedido.

Durante esse fluxo, ele publica mensagens Kafka em tópicos usados para coordenar ações com serviços dependentes:

- `inventory.commands`
- `fulfillment.commands`
- `payment.commands`
- `shipment.commands`
- `order.events`

Esses tópicos não fazem parte da lista de tópicos canônicos de domínio documentados em `docs/contracts/kafka-events.md`.

A dúvida arquitetural é se esses tópicos devem ser documentados como tópicos internos da saga ou migrados para nomes canônicos.

## Decisão

Os tópicos serão documentados como **tópicos internos de saga do OrderService**.

Eles não serão tratados como eventos canônicos públicos neste momento.

A nomenclatura atual será mantida para representar comandos internos de orquestração:

- `inventory.commands`
- `fulfillment.commands`
- `payment.commands`
- `shipment.commands`

O tópico `order.events` será documentado como tópico interno de eventos do contexto de pedidos, usado pela saga e por consumidores controlados.

Eventos públicos de domínio devem seguir nomes canônicos separados, por exemplo:

- `order.created`
- `order.confirmed`
- `order.cancelled`
- `payment.approved`
- `payment.rejected`
- `shipment.created`
- `shipment.cancelled`

## Justificativa

Comandos internos de saga e eventos canônicos de domínio têm objetivos diferentes.

Comandos internos representam intenção de execução dentro de um fluxo orquestrado. Exemplos:

- reservar estoque;
- iniciar captura de pagamento;
- acionar criação de entrega;
- validar capacidade de fulfillment.

Eventos canônicos representam fatos de negócio já ocorridos, com contrato estável e potencial consumo por múltiplos domínios. Exemplos:

- pedido criado;
- pagamento aprovado;
- entrega criada;
- pedido cancelado.

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

## Regra arquitetural

Tópicos terminados em `.commands` representam comandos internos de orquestração.

Eles não devem ser consumidos livremente por outros domínios e não devem ser tratados como eventos canônicos.

Eventos canônicos devem representar fatos de negócio já ocorridos, ter contrato versionado, ownership claro e semântica estável.

## Critério de promoção para tópico canônico

Um tópico interno só deve ser promovido para tópico canônico quando:

1. for consumido por múltiplos domínios independentes;
2. representar um fato de negócio estável;
3. tiver contrato versionado;
4. tiver owner definido;
5. for aprovado por nova ADR.

## Decisão final

Manter os tópicos atuais como internos de saga e documentá-los no `docs/contracts/kafka-events.md`.
