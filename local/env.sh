# Variáveis do ambiente local: todo comando AWS e Terraform vai para o moto, e não para a conta real.
# Uso: source local/env.sh (o Makefile já faz isso nos alvos local-*).

unset AWS_PROFILE
export AWS_ENDPOINT_URL="http://localhost:5000"
# A API S3 Control (tags do bucket) põe o account id na frente do host; lvh.me resolve qualquer subdomínio para 127.0.0.1.
export AWS_ENDPOINT_URL_S3_CONTROL="http://lvh.me:5000"
export AWS_ACCESS_KEY_ID="test"
export AWS_SECRET_ACCESS_KEY="test"
export AWS_REGION="us-east-2"
# Diretório de trabalho do Terraform separado do ambiente real (infra/.terraform).
export TF_DATA_DIR=".terraform-local"

# Conta fictícia do moto.
export LOCAL_ACCOUNT_ID="123456789012"
