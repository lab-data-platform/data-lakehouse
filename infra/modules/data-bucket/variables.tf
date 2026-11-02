variable "name" {
  description = "Nome do bucket (global na AWS)."
  type        = string
}

variable "versioning" {
  description = "Liga o versionamento. Útil no bronze (protege o dado bruto); dispensável em Iceberg, que já tem snapshots."
  type        = bool
  default     = false
}

variable "expiration_days" {
  description = "Apaga os objetos após N dias. null = nunca expira."
  type        = number
  default     = null
}

variable "noncurrent_expiration_days" {
  description = "Com versionamento, apaga as versões antigas após N dias."
  type        = number
  default     = 30
}

variable "force_destroy" {
  description = "Permite destruir o bucket mesmo com objetos dentro."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags específicas do bucket, somadas às default_tags do provider."
  type        = map(string)
  default     = {}
}
