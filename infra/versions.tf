terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # Configuração parcial: bucket, key e região são passados no `make init`.
  # O bucket de state é criado pelo data-foundation/bootstrap.
  backend "s3" {
    encrypt      = true
    use_lockfile = true
  }
}
