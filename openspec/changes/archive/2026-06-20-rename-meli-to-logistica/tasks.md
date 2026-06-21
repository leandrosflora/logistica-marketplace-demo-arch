## 1. Renomear arquivos com "meli" no nome

- [x] 1.1 Renomear `docs/c4/meli-envios-checkout-domain-level3.puml` → `docs/c4/logistica-envios-checkout-domain-level3.puml`
- [x] 1.2 Renomear `docs/c4/meli-envios-order-saga-level3.puml` → `docs/c4/logistica-envios-order-saga-level3.puml`
- [x] 1.3 Renomear `docs/c4/meli-envios-shipping-promise-domain-level3.puml` → `docs/c4/logistica-envios-shipping-promise-domain-level3.puml`
- [x] 1.4 Renomear `docs/c4/meli-envios-checkout-domain-level3.svg` → `docs/c4/logistica-envios-checkout-domain-level3.svg`
- [x] 1.5 Renomear `docs/c4/meli-envios-order-saga-level3.svg` → `docs/c4/logistica-envios-order-saga-level3.svg`
- [x] 1.6 Renomear `docs/c4/meli-envios-shipping-promise-domain-level3.svg` → `docs/c4/logistica-envios-shipping-promise-domain-level3.svg`
- [x] 1.7 Renomear `docs/contracts/meli-envios-apis.openapi.yaml` → `docs/contracts/logistica-envios-apis.openapi.yaml`

## 2. Atualizar docker-compose.yml

- [x] 2.1 Substituir `container_name: meli-envios-kafka` → `logistica-envios-kafka`
- [x] 2.2 Substituir `container_name: meli-envios-kafka-ui` → `logistica-envios-kafka-ui`
- [x] 2.3 Substituir `container_name: meli-envios-redis` → `logistica-envios-redis`
- [x] 2.4 Substituir `container_name: meli-envios-postgres` → `logistica-envios-postgres`
- [x] 2.5 Substituir `container_name: meli-envios-jaeger` → `logistica-envios-jaeger`
- [x] 2.6 Substituir `container_name: meli-envios-prometheus` → `logistica-envios-prometheus`
- [x] 2.7 Substituir `container_name: meli-envios-grafana` → `logistica-envios-grafana`

## 3. Atualizar conteúdo dos arquivos .puml renomeados

- [x] 3.1 Em `logistica-envios-checkout-domain-level3.puml`: substituir `Meli Envios` → `Logística Envios` em title/caption
- [x] 3.2 Em `logistica-envios-order-saga-level3.puml`: substituir `Meli Envios` → `Logística Envios` em title/caption
- [x] 3.3 Em `logistica-envios-shipping-promise-domain-level3.puml`: substituir `Meli Envios` → `Logística Envios` em title/caption

## 4. Atualizar documentação .md

- [x] 4.1 Em `README.md`: substituir referência a `meli-envios-apis.openapi.yaml` → `logistica-envios-apis.openapi.yaml`; substituir `Meli Envios` → `Logística Envios` onde aparecer como texto display
- [x] 4.2 Em `docs/contracts/README.md`: atualizar referência ao arquivo `.openapi.yaml` renomeado e ocorrências de `Meli Envios`
- [x] 4.3 Em `docs/contracts/api-contract-validation.md`: substituir `meli-envios-apis` → `logistica-envios-apis`
- [x] 4.4 Em `docs/contracts/kafka-schema-governance.md`: substituir `Meli Envios` → `Logística Envios`
- [x] 4.5 Em `docs/adr/0003-hexagonal-clean-architecture.md`: substituir ocorrências de `Meli Envios` ou `meli-envios`
- [x] 4.6 Em `docs/adr/0004-kafka-schema-versioning.md`: substituir ocorrências de `Meli Envios` ou `meli-envios`
- [x] 4.7 Em `docs/cicd/pipeline.md`: substituir `meli-envios` → `logistica-envios` e `Meli Envios` → `Logística Envios`
- [x] 4.8 Em `docs/glossary/domain-glossary.md`: substituir `Meli Envios` → `Logística Envios`
- [x] 4.9 Em `docs/runbooks/kafka-local-e2e.md`: substituir todos os `meli-envios-kafka` → `logistica-envios-kafka` nos comandos `docker exec`
- [x] 4.10 Em `docs/runbooks/observability-local.md`: substituir `meli-envios-*` → `logistica-envios-*` nos nomes de container
- [x] 4.11 Em `docs/security/security-architecture.md`: substituir `Meli Envios` → `Logística Envios`
- [x] 4.12 Em `docs/sequence-diagrams/README.md`: substituir `meli-envios` → `logistica-envios` e `Meli Envios` → `Logística Envios`
- [x] 4.13 Em `docs/services/audit-service.md`: substituir `Meli Envios` ou `meli-envios`
- [x] 4.14 Em `docs/services/tracking-service.md`: substituir `Meli Envios` ou `meli-envios`
- [x] 4.15 Em `docs/reviews/kafka-e2e-contract-review-2026-06-14.md`: substituir `Meli Envios` → `Logística Envios`
- [x] 4.16 Em `docs/reviews/kafka-e2e-validation-2026-06-14.md`: substituir `Meli Envios` → `Logística Envios`
- [x] 4.17 Em `docs/reviews/recent-prs-validation-2026-06-14.md`: substituir `Meli Envios` → `Logística Envios`
- [x] 4.18 Em `docs/prompts/codex-unit-tests-microservices-2026-06-14.md`: substituir `meli-envios` → `logistica-envios`

## 5. Atualizar arquivos .yaml/.yml de monitoramento

- [x] 5.1 Em `monitoring/grafana/provisioning/dashboards/dashboards.yaml`: substituir `meli-envios` → `logistica-envios` no campo `folder` ou `name`

## 6. Atualizar referências cruzadas aos arquivos renomeados

- [x] 6.1 Buscar e atualizar todas as referências a `meli-envios-checkout-domain-level3` nos docs → `logistica-envios-checkout-domain-level3`
- [x] 6.2 Buscar e atualizar todas as referências a `meli-envios-order-saga-level3` → `logistica-envios-order-saga-level3`
- [x] 6.3 Buscar e atualizar todas as referências a `meli-envios-shipping-promise-domain-level3` → `logistica-envios-shipping-promise-domain-level3`

## 7. Regenerar SVGs dos diagramas renomeados

- [x] 7.1 Regenerar SVG de `logistica-envios-checkout-domain-level3.puml`
- [x] 7.2 Regenerar SVG de `logistica-envios-order-saga-level3.puml`
- [x] 7.3 Regenerar SVG de `logistica-envios-shipping-promise-domain-level3.puml`
- [x] 7.4 Remover SVGs antigos com nome `meli-envios-*` (já substituídos pelos renomeados em 1.4–1.6)
