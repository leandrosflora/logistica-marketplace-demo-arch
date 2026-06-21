# ADR-0005 — Estratégia de Idempotência

## Status

Aceita

## Data

2026-06-20

## Contexto

Em um sistema distribuído com comunicação assíncrona via Kafka e síncrona via HTTP, falhas de rede e reprocessamentos são inevitáveis. Sem idempotência, operações duplicadas podem gerar pedidos duplicados, cobranças duplicadas e inconsistências de estoque.

Dois cenários distintos precisam de tratamento:

1. **APIs REST de comando**: cliente pode reenviar a mesma requisição por timeout ou retry.
2. **Consumers Kafka**: o broker garante at-least-once delivery; consumer pode processar a mesma mensagem mais de uma vez.

## Decisão

### APIs REST — Idempotency Key

Todo endpoint de comando (POST, PUT, PATCH que modifica estado) DEVE aceitar o header `x-idempotency-key`.

- O valor é um UUID gerado pelo client (BFF ou serviço chamador).
- O servidor armazena o resultado da primeira execução com aquela chave (Redis ou tabela de banco).
- Requisições subsequentes com a mesma chave retornam o resultado armazenado sem reprocessar.
- A chave expira após 24 horas (configurável por serviço).

```text
POST /v1/checkouts
x-idempotency-key: 550e8400-e29b-41d4-a716-446655440000
x-correlation-id: 7f000001-8b4d-4c2b-8c5a-123456789abc
```

### Consumers Kafka — Inbox Pattern

Todo consumer Kafka DEVE implementar o **Inbox Pattern**:

1. Ao receber mensagem, registrar o `eventId` na tabela `inbox_messages` com status `pending` dentro da mesma transação de banco.
2. Se `eventId` já existe na tabela: descartar mensagem (já processada) e fazer commit do offset.
3. Processar a mensagem e atualizar `inbox_messages` para `processed`.
4. Commit do offset Kafka somente após o processamento bem-sucedido.

### Producers Kafka — Outbox Pattern

Todo producer Kafka DEVE implementar o **Outbox Pattern**:

1. Ao invés de publicar diretamente no Kafka, gravar o evento na tabela `outbox_messages` dentro da mesma transação de negócio (unidade atômica).
2. Um `OutboxDispatcher` (background worker) lê os eventos pendentes e publica no Kafka.
3. Após confirmação do Kafka, marcar o evento como `published`.
4. Em caso de falha de publicação, o `OutboxDispatcher` retentará com backoff exponencial.

```
Transação de banco:
  INSERT INTO shipments (...)
  INSERT INTO outbox_messages (topic, payload, status='pending')
  COMMIT

OutboxDispatcher (background):
  SELECT * FROM outbox_messages WHERE status='pending'
  kafka.Produce(topic, payload)
  UPDATE outbox_messages SET status='published'
```

## Justificativa

O Outbox Pattern garante que eventos Kafka sejam publicados se e somente se a transação de banco for commitada, eliminando a janela de inconsistência entre persistência e publicação. O Inbox Pattern garante exactly-once processing no consumer mesmo com at-least-once delivery do Kafka.

## Consequências positivas

- Garantia de exactly-once semantics de ponta a ponta.
- Sem perda de eventos em caso de falha do producer.
- Sem processamento duplicado em caso de reentrega do Kafka.
- APIs REST seguras para retry automático do client.

## Consequências negativas

- Custo operacional: tabelas `outbox_messages` e `inbox_messages` em cada serviço com persistência.
- Latência adicional: evento não é publicado instantaneamente, mas via dispatcher assíncrono.
- Necessidade de limpeza periódica das tabelas (eventos processados/publicados antigos).

## Regras

1. Endpoints de comando DEVEM aceitar `x-idempotency-key` e armazenar o resultado por 24 horas.
2. Consumers Kafka DEVEM implementar Inbox Pattern com deduplicação por `eventId`.
3. Producers Kafka DEVEM implementar Outbox Pattern para eventos de domínio críticos.
4. O `OutboxDispatcher` DEVE usar retry com backoff exponencial: 1s, 2s, 4s, 8s, máximo 5 tentativas.
5. Tabelas de Inbox e Outbox DEVEM ter índice no campo `eventId`/`messageId` para deduplicação eficiente.
6. Retry em chamadas HTTP externas só é permitido quando a operação alvo é idempotente ou o retry usa o mesmo `x-idempotency-key`.

## Decisões relacionadas

- [ADR-0001 — Usar arquitetura orientada a eventos](0001-use-event-driven-architecture.md)
- [ADR-0002 — Saga Orchestrator no OrderService](0002-saga-orchestrator-pattern.md)
