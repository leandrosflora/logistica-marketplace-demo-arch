# Arquitetura de Segurança — Meli Envios

## Visão geral

Este documento descreve a estratégia de autenticação, autorização, propagação de identidade e gestão de segredos adotada no ecossistema Meli Envios.

---

## 1. Autenticação

### Mecanismo

O ecossistema usa **JWT (JSON Web Token)** com OAuth 2.0 / OpenID Connect para autenticação de usuários e serviços.

- **Usuários (buyer/seller):** autenticados via Identity Provider externo (IdP). O token JWT é emitido pelo IdP e validado pelo API Gateway ou diretamente pelos serviços.
- **Serviços internos (M2M):** autenticados via Client Credentials Flow do OAuth 2.0. Cada serviço possui um `client_id` e `client_secret` para obter tokens de acesso.

### Validação de token

- O **API Gateway** (ou BFF) valida o token JWT antes de encaminhar requisições para os microservices.
- Microservices podem re-validar o token para autorização fina, mas NÃO devem consultar o IdP em cada requisição — devem validar a assinatura JWT localmente com a chave pública.
- Tokens expirados devem ser rejeitados com HTTP 401.

### Claims obrigatórios no JWT

| Claim | Tipo | Descrição |
|---|---|---|
| `sub` | string | Identificador único do usuário (mapeado para `buyerId` ou `sellerId`) |
| `client_id` | string | Identificador da aplicação cliente |
| `scope` | string | Escopos autorizados (ex: `shipping:read`, `order:write`) |
| `exp` | number | Timestamp de expiração |
| `iat` | number | Timestamp de emissão |

---

## 2. Autorização

### Estratégia

Autorização baseada em **escopos JWT** no nível de endpoint, complementada por verificações de ownership no domínio.

- Endpoints de leitura: scope `<domain>:read` (ex: `shipping:read`, `order:read`).
- Endpoints de escrita/comando: scope `<domain>:write`.
- Verificação de ownership: o serviço deve verificar que o recurso acessado pertence ao `buyerId` ou `sellerId` do token antes de retornar dados.

### Exemplo de autorização

```csharp
// Controller
[Authorize(Policy = "ShippingWrite")]
[HttpPost("v1/checkout/{checkoutId}/quote")]
public async Task<IActionResult> RequestQuote(...)

// Policy
services.AddAuthorization(options =>
{
    options.AddPolicy("ShippingWrite", policy =>
        policy.RequireClaim("scope", "shipping:write"));
});
```

---

## 3. Propagação de Identidade

### Headers HTTP obrigatórios

Todo microservice DEVE aceitar, validar e propagar os seguintes headers em chamadas síncronas:

| Header | Obrigatoriedade | Descrição |
|---|---|---|
| `x-correlation-id` | Obrigatório em todas as requisições | UUID para rastreio de ponta a ponta. Se não recebido, o serviço DEVE gerar um novo. |
| `x-client-id` | Obrigatório quando chamado por BFF/canal | Identifica o canal consumidor (ex: `marketplace-web`, `seller-center`). |
| `x-idempotency-key` | Obrigatório em endpoints de comando (POST, PUT) | UUID gerado pelo client para garantir idempotência. Ver [ADR-0005](../adr/0005-idempotency-strategy.md). |
| `Authorization` | Obrigatório em todos os endpoints autenticados | Bearer token JWT. |

### Propagação em chamadas HTTP entre serviços

Quando um microservice chama outro via HTTP, DEVE propagar:
- `x-correlation-id` recebido na requisição original (nunca gerar um novo em chamadas de propagação).
- `Authorization` com token M2M do serviço chamador.
- `x-client-id` original, se recebido.

```csharp
// Exemplo de propagação via HttpClient
httpClient.DefaultRequestHeaders.Add("x-correlation-id", correlationId);
httpClient.DefaultRequestHeaders.Add("x-client-id", clientId);
```

### Propagação em eventos Kafka

O `correlationId` DEVE ser propagado no campo `correlationId` do envelope Kafka de todos os eventos canônicos e internos de saga.

```json
{
  "eventId": "uuid",
  "correlationId": "uuid-propagado-da-requisição-original",
  "producer": "order-service",
  "payload": {}
}
```

### Fluxo de identidade end-to-end

```text
Browser/App
  → BFF (gera x-correlation-id, x-client-id)
    → Checkout Service (propaga headers)
      → Shipping Promise Service (propaga x-correlation-id)
        → Product Catalog, Inventory, Routing, Carrier, Pricing (propagam x-correlation-id)
      ← resposta com promise
    ← resposta com cotação
  → Order Service (cria pedido)
    → Kafka: order.created (correlationId propagado)
      → Shipment Service (correlationId no envelope)
        → Kafka: shipment.created (correlationId propagado)
          → Tracking Service, Notification Service
```

---

## 4. Gestão de Segredos

### Regra fundamental

**Segredos NUNCA devem ser commitados no repositório**, incluindo:
- Connection strings de banco de dados.
- Bootstrap servers Kafka com credenciais.
- Redis passwords.
- API keys de transportadoras.
- Chaves privadas JWT.
- Client secrets OAuth.

### Desenvolvimento local

Para desenvolvimento local, usar **User Secrets do .NET**:

```bash
dotnet user-secrets init
dotnet user-secrets set "Kafka:BootstrapServers" "localhost:9092"
dotnet user-secrets set "ConnectionStrings:Default" "Host=localhost;Database=meli_envios;Username=meli;Password=meli"
```

Os valores do `docker-compose.yml` deste repositório (usuário `meli`, senha `meli`) são exclusivos para ambiente local e não devem ser usados em staging ou produção.

### Staging e Produção

Recomenda-se o uso de:
- **Azure Key Vault**: integração nativa com .NET via `Azure.Extensions.AspNetCore.Configuration.Secrets`.
- **HashiCorp Vault**: alternativa agnóstica de cloud.
- **Variáveis de ambiente via CI/CD**: aceitável para pipelines controlados.

```csharp
// Exemplo de integração com Azure Key Vault
builder.Configuration.AddAzureKeyVault(
    new Uri("https://<vault-name>.vault.azure.net/"),
    new DefaultAzureCredential());
```

### Segredos críticos do ecossistema

| Segredo | Serviço(s) afetado(s) | Mecanismo recomendado |
|---|---|---|
| Kafka Bootstrap Servers (com credenciais) | Todos com Kafka | Key Vault / Env var |
| Connection String Postgres | Order, Shipment, Tracking, Notification, Audit | Key Vault |
| Redis Connection String | Checkout, Shipping Promise | Key Vault |
| Client Secret OAuth (M2M) | Todos (chamadas HTTP entre serviços) | Key Vault |
| JWT Public Key / JWKS URI | Todos (validação de token) | Env var (não sensível) |
| API Key de Transportadoras | Carrier Service | Key Vault |

---

## 5. Segurança em Eventos Kafka

- Eventos Kafka **não devem conter dados sensíveis do usuário** além dos identificadores (`buyerId`, `sellerId`), a menos que o tópico esteja protegido com encryption at rest e in transit.
- Para ambiente local: Kafka sem TLS/SASL é aceitável.
- Para produção: Kafka DEVE usar TLS + SASL/SCRAM-SHA-512 com credenciais por serviço.
- Dados PII (nome, endereço completo) em payloads Kafka devem ser avaliados caso a caso e minimizados.

---

## Referências

- [ADR-0005 — Estratégia de Idempotência](../adr/0005-idempotency-strategy.md)
- [ADR-0006 — Stack de Observabilidade](../adr/0006-observability-stack.md)
- [Contratos Kafka](../contracts/kafka-events.md)
- [AGENTS.md](../../AGENTS.md)
