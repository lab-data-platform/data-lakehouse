# Um bucket por camada de dado, mais o bucket de resultados do Athena.

module "layer_bucket" {
  source   = "./modules/data-bucket"
  for_each = local.s3_layers

  name                       = "${local.name_prefix}-${each.key}-${local.account_id}"
  versioning                 = each.value.versioning
  noncurrent_expiration_days = var.bronze_noncurrent_retention_days
  force_destroy              = var.force_destroy

  tags = {
    Layer = each.key
  }
}

module "athena_results_bucket" {
  source = "./modules/data-bucket"

  name            = "${local.name_prefix}-athena-results-${local.account_id}"
  expiration_days = var.athena_results_retention_days
  force_destroy   = true

  tags = {
    Layer = "athena-results"
  }
}
