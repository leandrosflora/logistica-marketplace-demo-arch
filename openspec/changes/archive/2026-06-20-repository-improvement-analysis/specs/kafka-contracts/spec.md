## MODIFIED Requirements

### Requirement: Payload de shipment.created inclui sellerId
O contrato canônico do tópico `shipment.created` em `docs/contracts/kafka-events.md` SHALL incluir o campo `sellerId` no payload para permitir que `notification-service` notifique o seller sem lookup adicional.

#### Scenario: Payload de shipment.created contém sellerId
- **WHEN** o arquivo `docs/contracts/kafka-events.md` é lido na seção `shipment.created`
- **THEN** o payload canônico MUST conter o campo `sellerId: "uuid"` após o campo `orderId`
- **THEN** a descrição do campo MUST especificar que `sellerId` é propagado do `order.created` original para evitar lookup adicional no `notification-service`
- **THEN** o `schemaVersion` do evento DEVE ser atualizado para `1.1` (mudança backward-compatible)

## ADDED Requirements

### Requirement: Eventos canônicos ausentes documentados em kafka-events.md
O arquivo `docs/contracts/kafka-events.md` SHALL documentar os eventos canônicos mencionados nos ADRs mas não especificados: `order.confirmed`, `order.cancelled`, `payment.approved`, `payment.rejected`, `shipment.cancelled`.

#### Scenario: Evento order.confirmed documentado
- **WHEN** o arquivo `docs/contracts/kafka-events.md` é lido
- **THEN** ele MUST conter seção para `order.confirmed` com: producer (`order-service`), consumers (`notification-service`, `audit-service`), e payload canônico com `orderId`, `checkoutId`, `buyerId`, `sellerId`, `confirmedAt`

#### Scenario: Evento order.cancelled documentado
- **WHEN** o arquivo `docs/contracts/kafka-events.md` é lido
- **THEN** ele MUST conter seção para `order.cancelled` com: producer (`order-service`), consumers (`shipment-service`, `notification-service`, `audit-service`, `inventory-service`), e payload com `orderId`, `buyerId`, `sellerId`, `cancellationReason`, `cancelledAt`

#### Scenario: Evento payment.approved documentado
- **WHEN** o arquivo `docs/contracts/kafka-events.md` é lido
- **THEN** ele MUST conter seção para `payment.approved` com: producer (`payment-service`), consumers (`order-service`, `audit-service`), e payload com `orderId`, `paymentId`, `amount`, `currency`, `approvedAt`

#### Scenario: Evento payment.rejected documentado
- **WHEN** o arquivo `docs/contracts/kafka-events.md` é lido
- **THEN** ele MUST conter seção para `payment.rejected` com: producer (`payment-service`), consumers (`order-service`, `notification-service`, `audit-service`), e payload com `orderId`, `paymentId`, `rejectionCode`, `rejectedAt`

#### Scenario: Evento shipment.cancelled documentado
- **WHEN** o arquivo `docs/contracts/kafka-events.md` é lido
- **THEN** ele MUST conter seção para `shipment.cancelled` com: producer (`shipment-service`), consumers (`tracking-service`, `notification-service`, `order-service`, `audit-service`), e payload com `shipmentId`, `orderId`, `buyerId`, `sellerId`, `cancellationReason`, `cancelledAt`

#### Scenario: Matriz de contratos atualizada
- **WHEN** a matriz final de contratos canônicos em `kafka-events.md` é lida
- **THEN** ela MUST incluir os 5 novos eventos na tabela com suas colunas: Tópico, Producer, Consumers, Payload obrigatório, Status
