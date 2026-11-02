# Contrato publicado por este repositório no SSM Parameter Store.
# Consumidores: data-ingestion (bronze) e o dbt do lake (silver e gold).
# Catálogo em data-platform/docs/contratos.md: mudar um nome aqui é mudança de contrato.

locals {
  contract = merge(
    { for k, b in module.layer_bucket : "${k}_bucket" => b.name },
    { for k, db in aws_glue_catalog_database.layer : "glue_database_${k}" => db.name },
    {
      athena_results_bucket = module.athena_results_bucket.name
      athena_workgroup      = aws_athena_workgroup.this.name
    },
  )
}

resource "aws_ssm_parameter" "contract" {
  for_each = local.contract

  name  = "${local.ssm_prefix}/${each.key}"
  type  = "String"
  value = each.value
}
