#!/usr/bin/env bash
# Prepara o moto com o que, na conta real, vem do data-foundation:
# o bucket de state do Terraform e o contrato /lab-data/dev/foundation/*.
set -euo pipefail
source "$(dirname "$0")/env.sh"

aws s3api create-bucket --bucket "lab-data-tfstate-${LOCAL_ACCOUNT_ID}" \
  --create-bucket-configuration LocationConstraint="${AWS_REGION}" >/dev/null

put() { aws ssm put-parameter --overwrite --type String --name "/lab-data/dev/foundation/$1" --value "$2" >/dev/null; }
put name_prefix      "lab-data-dev"
put account_id       "${LOCAL_ACCOUNT_ID}"
put region           "${AWS_REGION}"
put alerts_topic_arn "arn:aws:sns:${AWS_REGION}:${LOCAL_ACCOUNT_ID}:lab-data-dev-alerts"

echo "moto pronto: bucket de state e contrato do foundation simulados."
