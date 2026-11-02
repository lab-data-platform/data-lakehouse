#!/usr/bin/env bash
# Confere, no moto, os recursos que o `terraform apply` local criou.
set -euo pipefail
source "$(dirname "$0")/env.sh"

falhas=0
check() {
  local descricao=$1 esperado=$2 obtido=$3
  if [[ "$obtido" == "$esperado" ]]; then
    echo "  ok    $descricao"
  else
    echo "  FALHA $descricao: esperado '$esperado', obtido '$obtido'"
    falhas=$((falhas + 1))
  fi
}

echo "Verificando o lakehouse no moto:"
for camada in bronze silver gold; do
  bucket="lab-data-dev-${camada}-${LOCAL_ACCOUNT_ID}"
  check "bucket $bucket existe" "$bucket" "$(aws s3api list-buckets --query "Buckets[?Name=='$bucket'].Name" --output text)"
  check "bucket $bucket sem acesso público" "True" "$(aws s3api get-public-access-block --bucket "$bucket" --query 'PublicAccessBlockConfiguration.BlockPublicPolicy' --output text)"
  check "database lab_data_dev_${camada}" "s3://${bucket}/" "$(aws glue get-database --name "lab_data_dev_${camada}" --query 'Database.LocationUri' --output text)"
done
check "bronze versionado" "Enabled" "$(aws s3api get-bucket-versioning --bucket "lab-data-dev-bronze-${LOCAL_ACCOUNT_ID}" --query Status --output text)"
check "workgroup com limite de 1 GB" "1073741824" "$(aws athena get-work-group --work-group lab-data-dev --query 'WorkGroup.Configuration.BytesScannedCutoffPerQuery' --output text)"
check "contrato com 8 parâmetros" "8" "$(aws ssm get-parameters-by-path --path /lab-data/dev/lakehouse --query 'length(Parameters)' --output text)"

if (( falhas > 0 )); then
  echo "$falhas verificação(ões) falharam."
  exit 1
fi
echo "Tudo certo."
