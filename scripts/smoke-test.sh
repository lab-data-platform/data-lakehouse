#!/usr/bin/env bash
# Smoke test do lakehouse na conta real (nível 3): cria uma tabela Iceberg na silver,
# insere e consulta uma linha pelo workgroup da plataforma e apaga tudo no final.
# Usa só o contrato publicado no SSM. Custo: centavos (poucos KB escaneados).
set -euo pipefail

ENV="${ENV:-dev}"
SSM="/lab-data/${ENV}/lakehouse"
param() { aws ssm get-parameter --name "${SSM}/$1" --query Parameter.Value --output text; }

WORKGROUP=$(param athena_workgroup)
DATABASE=$(param glue_database_silver)
BUCKET=$(param silver_bucket)
TABLE="smoke_test_$(date +%Y%m%d%H%M%S)"
LOCATION="s3://${BUCKET}/_smoke_test/${TABLE}/"

# Roda uma consulta no Athena e espera terminar. Imprime o id da execução.
athena() {
  local id state
  id=$(aws athena start-query-execution --work-group "$WORKGROUP" \
    --query-execution-context Database="$DATABASE" \
    --query-string "$1" --query QueryExecutionId --output text)
  while :; do
    state=$(aws athena get-query-execution --query-execution-id "$id" --query QueryExecution.Status.State --output text)
    case "$state" in
      SUCCEEDED) echo "$id"; return 0 ;;
      FAILED | CANCELLED)
        echo "Consulta falhou ($state): $1" >&2
        aws athena get-query-execution --query-execution-id "$id" \
          --query QueryExecution.Status.StateChangeReason --output text >&2
        return 1 ;;
      *) sleep 1 ;;
    esac
  done
}

limpar() {
  echo "Limpando: tabela ${DATABASE}.${TABLE} e ${LOCATION}"
  athena "DROP TABLE IF EXISTS ${TABLE}" >/dev/null || true
  aws s3 rm "$LOCATION" --recursive --only-show-errors || true
}
trap limpar EXIT

echo "Workgroup: ${WORKGROUP} · Database: ${DATABASE} · Tabela: ${TABLE}"

echo "1/3 Criando tabela Iceberg..."
athena "CREATE TABLE ${TABLE} (id int, status string) LOCATION '${LOCATION}' TBLPROPERTIES ('table_type' = 'ICEBERG')" >/dev/null

echo "2/3 Inserindo uma linha..."
athena "INSERT INTO ${TABLE} VALUES (1, 'ok')" >/dev/null

echo "3/3 Consultando..."
id=$(athena "SELECT status FROM ${TABLE} WHERE id = 1")
resultado=$(aws athena get-query-results --query-execution-id "$id" --query 'ResultSet.Rows[1].Data[0].VarCharValue' --output text)

if [[ "$resultado" == "ok" ]]; then
  echo "✅ Smoke test passou: o lakehouse cria, grava e consulta tabelas Iceberg."
else
  echo "❌ Smoke test falhou: esperado 'ok', obtido '${resultado}'." >&2
  exit 1
fi
