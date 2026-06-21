## ADDED Requirements

### Requirement: Glossário de domínio com termos de logística e envios
O repositório SHALL conter um arquivo `docs/glossary/domain-glossary.md` com definições formais dos termos do domínio Meli Envios usados em contratos, ADRs, diagramas e código.

#### Scenario: Glossário contém termos do domínio de envios
- **WHEN** o arquivo `docs/glossary/domain-glossary.md` é lido
- **THEN** ele MUST conter definição dos termos: Checkout, Shipping Promise, SKU, Seller, Buyer, Fulfillment Center (CD), Carrier, Route, Service Level, SLA, SLO, Shipment, Label, Tracking Code, Tracking Event, Delivery Exception, Order, Package, Cutoff, Hub, Malha Logística, Same Day, Next Day, Standard, Subsídio de Frete, Corridor

#### Scenario: Cada termo tem definição e contexto de uso
- **WHEN** um termo é consultado no glossário
- **THEN** ele MUST conter: nome, definição (1-3 frases), contexto de uso (em qual serviço ou contrato aparece), e termos relacionados

#### Scenario: Glossário referenciado no AGENTS.md
- **WHEN** o `AGENTS.md` é lido
- **THEN** ele MUST referenciar `docs/glossary/domain-glossary.md` como leitura obrigatória antes de gerar código relacionado ao domínio de envios
