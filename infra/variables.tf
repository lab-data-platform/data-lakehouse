variable "platform" {
  description = "Nome da plataforma, usado nos caminhos do contrato SSM."
  type        = string
  default     = "lab-data"
}

variable "environment" {
  description = "Ambiente da plataforma."
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "prd"], var.environment)
    error_message = "environment deve ser dev ou prd."
  }
}

variable "aws_region" {
  description = "Região AWS da plataforma (única liberada no plano gratuito, ADR-0013)."
  type        = string
  default     = "us-east-2"
}

variable "aws_profile" {
  description = "Profile do AWS CLI. null no ambiente local (credenciais via variáveis de ambiente)."
  type        = string
  default     = "lab-data"
}

variable "s3_use_path_style" {
  description = "Endereça o S3 por path style. Necessário só no emulador local (moto)."
  type        = bool
  default     = false
}

variable "layers" {
  description = <<-EOT
    Camadas de dado ligadas. A plataforma é construída camada a camada:
    começa só com o bronze; silver e gold entram depois, acrescentando-as aqui.
  EOT
  type        = set(string)
  default     = ["bronze"]

  validation {
    condition     = length(setsubtract(var.layers, ["bronze", "silver", "gold"])) == 0
    error_message = "layers só aceita bronze, silver e gold."
  }

  validation {
    condition     = contains(var.layers, "bronze")
    error_message = "O bronze é obrigatório: é nele que a ingestão grava."
  }
}

variable "layer_storage" {
  description = <<-EOT
    Implementação de armazenamento de cada camada de dado. Hoje só existe "s3" (bucket comum + Glue Catalog).
    "s3tables" (S3 Tables, Iceberg gerenciado) está em avaliação para a silver, no ADR-0014.
  EOT
  type        = map(string)
  default = {
    bronze = "s3"
    silver = "s3"
    gold   = "s3"
  }

  validation {
    condition     = toset(keys(var.layer_storage)) == toset(["bronze", "silver", "gold"])
    error_message = "layer_storage deve definir exatamente as camadas bronze, silver e gold."
  }

  validation {
    condition     = alltrue([for v in values(var.layer_storage) : v == "s3"])
    error_message = "Implementação de armazenamento não suportada. Hoje só existe \"s3\"; \"s3tables\" está em avaliação (ADR-0014)."
  }
}

variable "bronze_noncurrent_retention_days" {
  description = "Dias que as versões antigas de objetos do bronze ficam guardadas."
  type        = number
  default     = 30
}

variable "athena_results_retention_days" {
  description = "Dias que os resultados das consultas do Athena ficam guardados."
  type        = number
  default     = 7
}

variable "athena_bytes_scanned_cutoff" {
  description = "Limite de bytes escaneados por consulta no Athena. Acima disso a consulta é cancelada. Padrão: 1 GB."
  type        = number
  default     = 1073741824

  validation {
    condition     = var.athena_bytes_scanned_cutoff >= 10485760
    error_message = "O Athena exige um limite mínimo de 10 MB (10485760 bytes)."
  }
}

variable "force_destroy" {
  description = "Permite `make destroy` com dados nos buckets. Mantenha true só em dev."
  type        = bool
  default     = true
}
