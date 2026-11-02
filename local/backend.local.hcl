# Backend S3 apontando para o moto. O bucket é criado pelo local/seed.sh.
bucket                      = "lab-data-tfstate-123456789012"
key                         = "lakehouse/dev/terraform.tfstate"
region                      = "us-east-2"
use_path_style              = true
skip_credentials_validation = true
skip_requesting_account_id  = true
skip_metadata_api_check     = true
endpoints = {
  s3  = "http://localhost:5000"
  sts = "http://localhost:5000"
}
