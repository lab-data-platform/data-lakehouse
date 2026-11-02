provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile

  # Ambiente local (moto): os endpoints vêm das variáveis AWS_ENDPOINT_URL* e o S3 usa path style.
  s3_use_path_style = var.s3_use_path_style

  # Tags aplicadas automaticamente em todo recurso (convenções no data-platform).
  default_tags {
    tags = {
      Platform    = var.platform
      Environment = var.environment
      Component   = "lakehouse"
      ManagedBy   = "terraform"
      Repository  = "data-lakehouse"
    }
  }
}

# Contrato do data-foundation: este repositório não conhece o state nem o código dele,
# só os parâmetros publicados no SSM (data-platform/docs/contratos.md).
data "aws_ssm_parameter" "foundation" {
  for_each = toset(["name_prefix", "account_id"])

  name = "/${var.platform}/${var.environment}/foundation/${each.key}"
}

locals {
  name_prefix = data.aws_ssm_parameter.foundation["name_prefix"].insecure_value
  account_id  = data.aws_ssm_parameter.foundation["account_id"].insecure_value

  # Raiz dos parâmetros SSM publicados por este repositório.
  ssm_prefix = "/${var.platform}/${var.environment}/lakehouse"

  # Databases do Glue usam "_", porque o Athena não aceita "-" em nomes.
  glue_prefix = replace(local.name_prefix, "-", "_")

  # Definição das camadas de dado (arquitetura medalhão). Só as listadas em var.layers são criadas.
  layer_definitions = {
    bronze = {
      description = "Dado bruto, como veio da fonte, mais os metadados de ingestão"
      versioning  = true
    }
    silver = {
      description = "Dado limpo, tipado e deduplicado, no modelo da fonte (Iceberg)"
      versioning  = false
    }
    gold = {
      description = "Entidades de negócio conformadas, prontas para consumo e para o DW (Iceberg)"
      versioning  = false
    }
  }

  # Camadas ligadas e armazenadas em bucket S3 comum + Glue Catalog (implementação "s3").
  s3_layers = {
    for k, v in local.layer_definitions : k => v
    if contains(var.layers, k) && var.layer_storage[k] == "s3"
  }
}
