# Governança de Schemas Kafka — Logística Envios

## Objetivo

Documentar o processo de evolução, versionamento e ownership dos schemas dos eventos Kafka canônicos do ecossistema Logística Envios.

Decisão arquitetural relacionada: [ADR-0004 — Estratégia de Versionamento de Schemas Kafka](../adr/0004-kafka-schema-versioning.md).

---

## 1. Tipos de Mudança e Impacto

| Tipo de mudança | Compatibilidade | Ação |
|---|---|---|
| Adição de campo opcional ao `payload` | Backward-compatible | Incrementar minor version: `1.0` → `1.1` |
| Adição de campo obrigatório com valor default | Backward-compatible (com cuidado) | Incrementar minor version; documentar o default |
| Remoção de campo | **Breaking** | Nova versão major: `1.x` → `2.0` + novo ADR obrigatório |
| Renaming de campo | **Breaking** | Nova versão major: `1.x` → `2.0` + novo ADR obrigatório |
| Mudança de tipo de campo | **Breaking** | Nova versão major: `1.x` → `2.0` + novo ADR obrigatório |
| Mudança de semântica de campo | **Breaking** | Nova versão major: `1.x` → `2.0` + novo ADR obrigatório |
| Novo tópico canônico | Não aplicável | PR com spec no `kafka-events.md` + ADR se novo domínio |

---

## 2. Processo de Evolução de Contrato

### Mudança Backward-Compatible (minor)

1. Criar PR com alteração no payload em `docs/contracts/kafka-events.md`.
2. Atualizar `schemaVersion` no envelope do evento (ex: `1.0` → `1.1`).
3. Notificar os owners dos consumers via comentário no PR (lista abaixo na tabela de ownership).
4. PR aprovado por pelo menos um revisor e pelo owner do tópico.
5. Merge.

### Mudança Breaking (major)

1. **Antes de qualquer implementação**, criar ADR documentando a mudança e justificativa.
2. ADR deve especificar período de coexistência mínimo (default: 30 dias ou 2 deploys em produção).
3. Criar PR com nova versão do schema em `kafka-events.md`.
4. Atualizar `schemaVersion` para nova versão major (ex: `1.x` → `2.0`).
5. Producer passa a publicar nova versão do payload.
6. Consumers continuam funcionando com versão antiga durante o período de coexistência.
7. Após migração de todos os consumers: deprecar versão antiga com data de remoção.
8. Atualizar tabela de ownership neste documento.

---

## 3. Padrão Tolerant Reader (obrigatório)

Todo consumer Kafka DEVE ignorar campos desconhecidos no payload. Isso permite que novos campos sejam adicionados sem quebrar consumers existentes.

### .NET / System.Text.Json (padrão)

```csharp
// System.Text.Json ignora campos desconhecidos por padrão
var options = new JsonSerializerOptions
{
    PropertyNameCaseInsensitive = true
};
var payload = JsonSerializer.Deserialize<OrderCreatedPayload>(json, options);
```

### .NET / Newtonsoft.Json

```csharp
var settings = new JsonSerializerSettings
{
    MissingMemberHandling = MissingMemberHandling.Ignore
};
var payload = JsonConvert.DeserializeObject<OrderCreatedPayload>(json, settings);
```

**Regra:** A presença ou ausência de campos desconhecidos NUNCA deve causar exceção. Se um campo obrigatório de negócio estiver ausente, o consumer deve logar o erro e mover a mensagem para DLQ (Dead Letter Queue), não lançar exceção de desserialização.

---

## 4. Tabela de Ownership de Tópicos

| Tópico | Owner do Schema | Service Producer | Consumers | Versão atual | Última mudança |
|---|---|---|---|---|---|
| `checkout.shipping.quote.requested` | Checkout Service | `checkout-service` | `shipping-promise-service`, `audit-service`, `analytics` | `1.0` | 2026-06-14 |
| `shipping.promise.calculated` | Shipping Promise Service | `shipping-promise-service` | `checkout-service`, `audit-service`, `analytics` | `1.0` | 2026-06-14 |
| `order.created` | Order Service | `order-service` | `shipment-service`, `notification-service`, `audit-service` | `1.0` | 2026-06-14 |
| `shipment.created` | Shipment Service | `shipment-service` | `tracking-service`, `notification-service`, `audit-service` | `1.1` | 2026-06-20 (adicionado `sellerId`) |
| `shipment.status.updated` | Tracking Service | `tracking-service` | `notification-service`, `audit-service`, `order-service` | `1.0` | 2026-06-14 |
| `order.confirmed` | Order Service | `order-service` | `notification-service`, `audit-service` | `1.0` | 2026-06-20 (novo) |
| `order.cancelled` | Order Service | `order-service` | `shipment-service`, `notification-service`, `audit-service`, `inventory-service` | `1.0` | 2026-06-20 (novo) |
| `payment.approved` | Payment Service | `payment-service` | `order-service`, `audit-service` | `1.0` | 2026-06-20 (novo) |
| `payment.rejected` | Payment Service | `payment-service` | `order-service`, `notification-service`, `audit-service` | `1.0` | 2026-06-20 (novo) |
| `shipment.cancelled` | Shipment Service | `shipment-service` | `tracking-service`, `notification-service`, `order-service`, `audit-service` | `1.0` | 2026-06-20 (novo) |

---

## 5. Dead Letter Queue (DLQ)

Cada tópico canônico DEVE ter um tópico DLQ correspondente no formato `<topico>.dlq`:

| Tópico | DLQ |
|---|---|
| `order.created` | `order.created.dlq` |
| `shipment.created` | `shipment.created.dlq` |
| `shipment.status.updated` | `shipment.status.updated.dlq` |
| *(e assim por diante)* | |

Mensagens enviadas para DLQ DEVEM conter o motivo da falha nos headers Kafka:
- `dlq-reason`: descrição textual da falha.
- `dlq-original-topic`: tópico original.
- `dlq-retry-count`: número de tentativas.
- `dlq-correlation-id`: correlationId da mensagem original.

---

## 6. Referências

- [ADR-0004 — Estratégia de Versionamento de Schemas](../adr/0004-kafka-schema-versioning.md)
- [ADR-0001 — Usar arquitetura orientada a eventos](../adr/0001-use-event-driven-architecture.md)
- [Contratos Kafka](kafka-events.md)
