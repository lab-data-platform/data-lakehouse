# Catálogo: um database do Glue por camada, apontando para o bucket da camada.
# As tabelas são criadas depois, pela ingestão (bronze) e pelo dbt (silver e gold).

resource "aws_glue_catalog_database" "layer" {
  for_each = local.s3_layers

  name         = "${local.glue_prefix}_${each.key}"
  description  = each.value.description
  location_uri = "s3://${module.layer_bucket[each.key].name}/"

  tags = {
    Layer = each.key
  }
}
