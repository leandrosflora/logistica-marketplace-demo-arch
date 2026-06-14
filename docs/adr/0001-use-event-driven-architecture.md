# ADR 0001: Usar arquitetura orientada a eventos para fluxos pós-pedido

## Status

Aceita.

## Contexto

Após a confirmação do pedido, vários domínios precisam reagir:

- criação de shipment;
- geração de etiqueta;
- tracking;
- notificação;
- auditoria;
- analytics;
- atualização de status.

Acoplar tudo de forma síncrona aumenta latência, reduz resiliência e torna o checkout frágil.

## Decisão

Usar Kafka para integração assíncrona entre domínios após eventos relevantes, principalmente a partir de `order.created`.

Fluxos de consulta em tempo real, como cotação de frete, permanecem síncronos quando a experiência do usuário exige resposta imediata.

## Consequências positivas

- Menor acoplamento entre serviços.
- Melhor tolerância a falhas.
- Possibilidade de reprocessamento.
- Escala independente por consumidor.
- Auditoria e rastreabilidade mais simples.

## Consequências negativas

- Consistência eventual.
- Necessidade de idempotência nos consumidores.
- Maior complexidade operacional.
- Necessidade de schema governance.

## Regras

- Todo consumidor deve ser idempotente.
- Todo evento deve carregar `eventId`, `correlationId`, `occurredAt` e `schemaVersion`.
- Mudança incompatível de payload exige nova versão de schema.
