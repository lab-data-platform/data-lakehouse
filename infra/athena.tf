# Workgroup da plataforma: toda consulta ao lake passa por ele, com limite de custo por consulta.

resource "aws_athena_workgroup" "this" {
  name        = local.name_prefix
  description = "Consultas ao lakehouse da plataforma ${var.platform}"

  # Em `make destroy`, apaga junto as consultas salvas e o histórico do workgroup.
  force_destroy = true

  configuration {
    # Quem usa o workgroup não pode trocar o local dos resultados nem o limite.
    enforce_workgroup_configuration    = true
    publish_cloudwatch_metrics_enabled = true
    bytes_scanned_cutoff_per_query     = var.athena_bytes_scanned_cutoff

    engine_version {
      selected_engine_version = "Athena engine version 3"
    }

    result_configuration {
      output_location = "s3://${module.athena_results_bucket.name}/"

      encryption_configuration {
        encryption_option = "SSE_S3"
      }
    }
  }
}
