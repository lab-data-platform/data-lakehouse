# data-lakehouse

Armazenamento e catálogo das camadas de dado da plataforma `lab-data`: um bucket S3 e um database do Glue por camada, mais o workgroup do Athena. A plataforma é construída **camada a camada**: hoje existe só o **bronze**; silver e gold entram depois. Visão geral em [data-platform](https://github.com/lab-data-platform/data-platform).

> ⏳ **Camada 3 em construção, começando pelo bronze.** Silver e gold entram depois, uma de cada vez; o projeto dbt do lake, na **camada 5**. Escopo e critério de pronto no [ROADMAP](https://github.com/lab-data-platform/data-platform/blob/main/ROADMAP.md#camada-3--lakehouse).

## Recursos na AWS (previstos)

O que este repositório cria na conta. **Região:** `us-east-2` (Ohio). No console, confira se o seletor de região (canto superior direito) está em **Ohio**.

| Serviço AWS | Recurso | Para que serve | Região | Custo | Código | Onde ver no console |
|---|---|---|---|---|---|---|
| **Amazon S3** | Bucket `lab-data-dev-bronze-<account_id>` | Dado bruto, como veio da fonte. **Versionado** (versões antigas expiram em 30 dias), criptografado, sem acesso público, só TLS | `us-east-2` | centavos por GB guardado | `infra/storage.tf` | [S3 → Buckets](https://us-east-2.console.aws.amazon.com/s3/buckets?region=us-east-2) |
| **Amazon S3** | Bucket `lab-data-dev-athena-results-<account_id>` | Resultados das consultas do Athena; expiram em 7 dias | `us-east-2` | centavos | `infra/storage.tf` | [S3 → Buckets](https://us-east-2.console.aws.amazon.com/s3/buckets?region=us-east-2) |
| **AWS Glue** (Data Catalog) | Database `lab_data_dev_bronze` | Catálogo das tabelas do bronze, apontando para o bucket do bronze | `us-east-2` | grátis (primeiro milhão de objetos) | `infra/catalog.tf` | [Glue → Databases](https://us-east-2.console.aws.amazon.com/glue/home?region=us-east-2#/v2/data-catalog/databases) |
| **Amazon Athena** | Workgroup `lab-data-dev` | Consultas SQL no lake: engine v3, resultados no bucket próprio, **limite de 1 GB escaneado por consulta** | `us-east-2` | US$ 5 por TB escaneado (no máximo ~US$ 0,005 por consulta) | `infra/athena.tf` | [Athena → Workgroups](https://us-east-2.console.aws.amazon.com/athena/home?region=us-east-2#/workgroups) |
| **AWS Systems Manager** (Parameter Store) | 4 parâmetros em `/lab-data/dev/lakehouse/` | Contrato para a ingestão e o dbt ([detalhe abaixo](#contrato)) | `us-east-2` | grátis (parâmetros *Standard*) | `infra/contract.tf` | [Parameter Store](https://us-east-2.console.aws.amazon.com/systems-manager/parameters?region=us-east-2) |

**Ainda sem dado:** as tabelas do bronze são criadas pela ingestão (camada 4).

**Próximas camadas:** silver e gold já estão definidas no código (`infra/main.tf`) e entram acrescentando-as à variável `layers`. Cada uma ganha o seu bucket (sem versionamento, porque o Iceberg já guarda snapshots), o seu database do Glue e os seus parâmetros no contrato.

**Armazenamento plugável:** a variável `layer_storage` define a implementação de cada camada. Hoje só existe `s3` (bucket comum + Glue Catalog); o **S3 Tables** na silver está em avaliação ([ADR-0014](https://github.com/lab-data-platform/data-platform/blob/main/docs/decisoes/0014-s3-tables-na-silver.md)).

Para listar pelo terminal tudo o que este repositório criou:

```bash
aws resourcegroupstaggingapi get-resources --region us-east-2 \
  --tag-filters Key=Repository,Values=data-lakehouse \
  --query 'ResourceTagMappingList[].ResourceARN' --output text
```

## Depende de

| Repositório | O que usa | Como |
|---|---|---|
| `data-foundation` | Bucket de state do Terraform | Backend S3 (`lakehouse/<env>/terraform.tfstate`) |
| `data-foundation` | `name_prefix` e `account_id` | Leitura do SSM em `/lab-data/<env>/foundation/` ([infra/main.tf](infra/main.tf)) |

## Estrutura

```
data-lakehouse/
├── infra/
│   ├── modules/data-bucket/   # bucket S3 com as proteções padrão (reutilizado em todas as camadas)
│   ├── tests/                 # terraform test com provider simulado
│   ├── main.tf                # provider, contrato do foundation, definição das camadas
│   ├── storage.tf             # buckets
│   ├── catalog.tf             # databases do Glue
│   ├── athena.tf              # workgroup
│   └── contract.tf            # contrato publicado no SSM
├── local/                     # ambiente local: moto em Docker, carga inicial e verificação
├── scripts/smoke-test.sh      # teste na conta real: arquivo + tabela no bronze
├── Makefile
├── CLAUDE.md
└── README.md
```

## Uso

```bash
make help         # lista os comandos
pre-commit install

# Nível 1 e 2: sem AWS
make test         # testes unitários
make local-up     # sobe o moto
make local-test   # aplica no moto, confere e destrói
make local-down

# Nível 3: conta real (o data-foundation precisa estar aplicado)
make init
make plan
make apply
make smoke-test   # grava um arquivo no bronze, cria a tabela, consulta e apaga
```

## Testes

| Nível | Comando | O que cobre |
|---|---|---|
| 1. Unitário | `make test` | Só o bronze por padrão, nomes, versionamento, workgroup (limite, engine, resultados), contrato SSM, silver e gold quando ligadas e validação das variáveis, com provider simulado (9 casos) |
| 2. Integração local | `make local-up` + `make local-test` | Aplica o stack inteiro no **moto** (S3, Glue, Athena e SSM emulados), confere 8 pontos com `local/verify.sh` e destrói |
| 3. Real | `make plan`, `make apply`, `make smoke-test` | Plano na conta `dev`; arquivo JSON gravado no bronze, tabela criada no Glue e consultada pelo workgroup, tudo apagado no final |

O ambiente local usa `lvh.me`, um domínio público que resolve qualquer subdomínio para `127.0.0.1`. Ele é necessário porque a API S3 Control (tags dos buckets) põe o account id na frente do endereço ([ADR-0012](https://github.com/lab-data-platform/data-platform/blob/main/docs/decisoes/0012-testes-locais.md)).

## Contrato

Publicado em `/lab-data/<env>/lakehouse/` ([catálogo de contratos](https://github.com/lab-data-platform/data-platform/blob/main/docs/contratos.md#data-lakehouse)):

| Parâmetro | Valor |
|---|---|
| `bronze_bucket` | Bucket do bronze |
| `glue_database_bronze` | Database do Glue do bronze |
| `athena_workgroup` | `lab-data-<env>` |
| `athena_results_bucket` | Bucket de resultados do Athena |

Quando silver e gold forem ligadas, entram `silver_bucket`, `gold_bucket`, `glue_database_silver` e `glue_database_gold`.

## Qualidade

| Verificação | Onde roda | O que cobre |
|---|---|---|
| Pré-commit | Na sua máquina, a cada `git commit` | Segredos (gitleaks, credenciais AWS, chaves privadas), YAML, espaços e fim de arquivo, formatação do Terraform, commit direto na `main` |
| CI | GitHub Actions ([ci.yml](.github/workflows/ci.yml)), em todo PR e push na `main` | Três jobs: **Terraform** (`fmt`, `validate`, `test`), **Integração local (moto)** e **pre-commit**; todos obrigatórios para o merge |

```bash
pre-commit install            # uma vez por clone: ativa os hooks
pre-commit run --all-files    # roda todos os hooks manualmente
```
