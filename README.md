# data-lakehouse

Armazenamento e catálogo de todas as camadas de dado da plataforma `lab-data`. Visão geral em [data-platform](../data-platform/README.md).

> ⬜ **Planejado.** Este repositório é construído na **camada 3** (infra do lake) e recebe o projeto dbt na **camada 5**. Escopo e critério de pronto em [ROADMAP.md](../data-platform/ROADMAP.md#camada-3--lakehouse).

## Recursos na AWS (previstos)

Nada foi criado ainda. Previsão para a camada 3, a confirmar no escopo. **Região:** `us-east-2` (Ohio).

| Serviço AWS | Recurso | Para que serve | Região | Custo | Código | Onde ver no console |
|---|---|---|---|---|---|---|
| **Amazon S3** | Buckets `lab-data-dev-bronze`, `-silver`, `-gold` (sufixo `-<account_id>`) | Uma camada de dado por bucket; criptografia, sem acesso público, só TLS, lifecycle | `us-east-2` | centavos (por GB guardado) | `infra/` | S3 → Buckets |
| **Amazon S3** | Bucket `lab-data-dev-athena-results-<account_id>` | Resultados das consultas do Athena, com expiração automática | `us-east-2` | centavos | `infra/` | S3 → Buckets |
| **AWS Glue** (Data Catalog) | Databases `lab_data_dev_bronze`, `_silver`, `_gold` | Catálogo das tabelas de cada camada | `us-east-2` | grátis (primeiro milhão de objetos) | `infra/` | Glue → Data Catalog → Databases |
| **Amazon Athena** | Workgroup `lab-data-dev` | Consultas SQL no lake, com limite de bytes por consulta | `us-east-2` | US$ 5 por TB escaneado | `infra/` | Athena → Workgroups |
| **AWS Systems Manager** (Parameter Store) | Parâmetros em `/lab-data/dev/lakehouse/` | Contrato para a ingestão e o dbt ([contratos](../data-platform/docs/contratos.md#data-lakehouse)) | `us-east-2` | grátis | `infra/contract.tf` | Parameter Store |

**Previsto (camada 5):** projeto dbt do lake (bronze → silver → gold, em Iceberg). Ele não cria recurso novo: grava tabelas nos buckets e databases acima.

## Estrutura prevista

```
data-lakehouse/
├── infra/          # Terraform (state: lakehouse/<env>/terraform.tfstate)
│   └── tests/
├── dbt/            # camada 5: dbt-athena, com target local em dbt-duckdb
├── local/          # moto (S3) em Docker
├── Makefile
├── CLAUDE.md
└── README.md
```

## Depende de

- `data-foundation`: bucket de state e contrato `/lab-data/<env>/foundation/*`
