# CLAUDE.md — data-lakehouse

Repositório do lake da plataforma `lab-data`. Regras gerais, arquitetura e contratos ficam no hub: [../data-platform/CLAUDE.md](../data-platform/CLAUDE.md). Leia esse arquivo primeiro.

## Específico deste repositório

- **Status: bronze aplicado na conta (etapa 3a).** Silver e gold entram depois, uma de cada vez, acrescentando-as à variável `layers` — não ligue uma camada nova sem o usuário pedir. O projeto dbt só entra na camada 5 ([roadmap](../data-platform/ROADMAP.md#camada-3--lakehouse)).
- Lê o contrato do `data-foundation` (`name_prefix`, `account_id`) pelo SSM; nunca fixe esses valores no código.
- Toda camada de dado nova passa pelo módulo `infra/modules/data-bucket`. A implementação de armazenamento de cada camada vem de `layer_storage`; hoje só existe `s3` (S3 Tables em avaliação, ADR-0014).
- Antes de entregar uma mudança: `make fmt`, `make test` e o ciclo local (`make local-up`, `make local-test`, `make local-down`).
- `apply`, `destroy` e `smoke-test` só com confirmação explícita do usuário. O `smoke-test` grava um arquivo e cria e apaga uma tabela no bronze da conta real.
