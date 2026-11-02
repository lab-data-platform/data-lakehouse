output "buckets" {
  description = "Bucket de cada camada de dado."
  value       = { for k, b in module.layer_bucket : k => b.name }
}

output "athena_results_bucket" {
  description = "Bucket de resultados do Athena."
  value       = module.athena_results_bucket.name
}

output "glue_databases" {
  description = "Database do Glue de cada camada."
  value       = { for k, db in aws_glue_catalog_database.layer : k => db.name }
}

output "athena_workgroup" {
  description = "Workgroup do Athena da plataforma."
  value       = aws_athena_workgroup.this.name
}

output "contract_parameters" {
  description = "Parâmetros SSM publicados como contrato."
  value       = sort([for p in aws_ssm_parameter.contract : p.name])
}
