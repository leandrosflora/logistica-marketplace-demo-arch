# ADR-0002 — Padrão Saga Orchestrator no OrderService

## Status

Aceita

## Data

2026-06-20

## Contexto

Após a confirmação do checkout, o `OrderService` precisa coordenar múltiplas ações em serviços independentes:

- Reservar estoque no `InventoryService`.
- Validar capacidade operacional no `FulfillmentCenterService`.
- Autorizar o pagamento no `PaymentService`.
- Criar a entrega no `ShipmentService`.

Cada uma dessas ações pode falhar, exigindo compensações (rollback) nas ações já concluídas.

Existem dois padrões principais para coordenar sagas distribuídas:

- **Choreography**: cada serviço reage a eventos de domínio publicados por outros.
- **Orchestrator**: um serviço central coordena a ordem das ações e os rollbacks.

## Decisão

Adotar o padrão **Saga Orchestrator** centralizado no `OrderService`, implementado pelo componente `OrderProcessManager`.

O `OrderProcessManager` é responsável por:

1. Publicar comandos nos tópicos internos de saga:
   - `inventory.commands` — para reservar/liberar estoque.
   - `fulfillment.commands` — para validar/ativar capacidade de fulfillment.
   - `payment.commands` — para autorizar/capturar/cancelar pagamento.
   - `shipment.commands` — para solicitar/cancelar criação de entrega.
2. Consumir respostas nesses tópicos internos.
3. Avançar para a próxima etapa ou iniciar compensações em caso de falha.
4. Publicar eventos canônicos de domínio ao final de cada transição relevante (`order.created`, `order.confirmed`, `order.cancelled`).

Os tópicos internos de saga são regidos pelo [ADR-0007](0007-order-service-internal-saga-topics.md).

## Justificativa

O padrão Orchestrator foi preferido ao Choreography pelas seguintes razões:

| Critério | Choreography | Orchestrator |
|---|---|---|
| Visibilidade do fluxo | Baixa — fluxo distribuído | Alta — fluxo centralizado |
| Capacidade de compensação | Complexa | Explícita e centralizada |
| Rastreabilidade | Requer correlação entre eventos | Nativa via estado do orquestrador |
| Acoplamento | Menor entre serviços | Maior no orquestrador |
| Debugging | Difícil | Mais simples |

Para um fluxo de criação de pedido com múltiplas compensações possíveis e requisitos de rastreabilidade regulatória, a visibilidade centralizada do Orchestrator supera a desvantagem de maior acoplamento no `OrderService`.

## Consequências positivas

- Fluxo da saga visível e depurável em um único componente.
- Compensações explícitas e controladas.
- Rastreabilidade do estado do pedido em qualquer ponto da saga.
- Facilita auditoria e compliance.

## Consequências negativas

- O `OrderService` se torna um ponto central de falha para o fluxo de criação de pedido.
- O `OrderProcessManager` precisa ser stateful para armazenar o estado corrente da saga.
- Mudanças no fluxo exigem alteração no `OrderService`.

## Regras

1. O `OrderProcessManager` é o único componente autorizado a publicar nos tópicos internos de saga (`*.commands`).
2. Serviços consumidores de comandos devem responder no mesmo tópico com envelope de resultado.
3. O estado da saga deve ser persistido em banco de dados (tabela `order_saga_state` ou equivalente) para suportar reprocessamento após falha.
4. Compensações devem ser idempotentes.
5. Eventos canônicos de domínio (`order.created`, `order.confirmed`, `order.cancelled`) só devem ser publicados pelo `OrderService`, não pelos consumers dos comandos internos.

## Decisões relacionadas

- [ADR-0007 — Tópicos internos de saga do OrderService](0007-order-service-internal-saga-topics.md)
- [ADR-0001 — Usar arquitetura orientada a eventos para fluxos pós-pedido](0001-use-event-driven-architecture.md)
