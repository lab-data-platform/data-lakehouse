# Testes unitários do lakehouse, com provider simulado: não acessam a AWS.
# O contrato do data-foundation (SSM) também é simulado.
# Rodar: make test

mock_provider "aws" {
  # O provider real devolve um JSON válido; o mock precisa fazer o mesmo para o bucket policy.
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }
}

override_data {
  target = data.aws_ssm_parameter.foundation["name_prefix"]
  values = {
    insecure_value = "lab-data-dev"
  }
}

override_data {
  target = data.aws_ssm_parameter.foundation["account_id"]
  values = {
    insecure_value = "123456789012"
  }
}

# --- Padrão: só o bronze ligado ---------------------------------------------

run "por_padrao_so_o_bronze_existe" {
  command = plan

  assert {
    condition     = keys(module.layer_bucket) == ["bronze"]
    error_message = "Por padrão, só a camada bronze deve ser criada."
  }

  assert {
    condition     = module.layer_bucket["bronze"].name == "lab-data-dev-bronze-123456789012"
    error_message = "O bucket do bronze deve se chamar <prefixo>-bronze-<account_id>."
  }

  assert {
    condition     = module.layer_bucket["bronze"].versioning_enabled
    error_message = "O bronze deve ser versionado, para proteger o dado bruto."
  }

  assert {
    condition     = module.athena_results_bucket.name == "lab-data-dev-athena-results-123456789012"
    error_message = "O bucket de resultados deve se chamar <prefixo>-athena-results-<account_id>."
  }
}

run "database_do_bronze_aponta_para_o_bucket" {
  command = plan

  assert {
    condition     = aws_glue_catalog_database.layer["bronze"].name == "lab_data_dev_bronze"
    error_message = "O database deve se chamar lab_data_<env>_bronze."
  }

  assert {
    condition     = aws_glue_catalog_database.layer["bronze"].location_uri == "s3://lab-data-dev-bronze-123456789012/"
    error_message = "O database do bronze deve apontar para o bucket do bronze."
  }
}

run "workgroup_tem_limite_de_custo" {
  command = plan

  assert {
    condition     = aws_athena_workgroup.this.name == "lab-data-dev"
    error_message = "O workgroup deve se chamar <prefixo>."
  }

  assert {
    condition     = aws_athena_workgroup.this.configuration[0].bytes_scanned_cutoff_per_query == 1073741824
    error_message = "O limite padrão por consulta deve ser 1 GB."
  }

  assert {
    condition     = aws_athena_workgroup.this.configuration[0].enforce_workgroup_configuration
    error_message = "A configuração do workgroup deve ser obrigatória para quem o usa."
  }

  assert {
    condition     = aws_athena_workgroup.this.configuration[0].engine_version[0].selected_engine_version == "Athena engine version 3"
    error_message = "O workgroup deve usar o Athena engine v3."
  }

  assert {
    condition     = aws_athena_workgroup.this.configuration[0].result_configuration[0].output_location == "s3://lab-data-dev-athena-results-123456789012/"
    error_message = "Os resultados devem ir para o bucket athena-results."
  }
}

run "contrato_do_bronze" {
  command = apply

  assert {
    condition = toset([for p in aws_ssm_parameter.contract : p.name]) == toset([
      "/lab-data/dev/lakehouse/athena_results_bucket",
      "/lab-data/dev/lakehouse/athena_workgroup",
      "/lab-data/dev/lakehouse/bronze_bucket",
      "/lab-data/dev/lakehouse/glue_database_bronze",
    ])
    error_message = "Os parâmetros do contrato mudaram: atualize data-platform/docs/contratos.md."
  }

  assert {
    condition     = aws_ssm_parameter.contract["glue_database_bronze"].value == "lab_data_dev_bronze"
    error_message = "O contrato deve publicar o nome do database do bronze."
  }
}

# --- Próximas camadas: o código já suporta silver e gold ---------------------

run "silver_e_gold_quando_ligadas" {
  command = apply

  variables {
    layers = ["bronze", "silver", "gold"]
  }

  assert {
    condition = {
      for k, b in module.layer_bucket : k => [b.name, b.versioning_enabled]
      } == {
      bronze = ["lab-data-dev-bronze-123456789012", true]
      silver = ["lab-data-dev-silver-123456789012", false]
      gold   = ["lab-data-dev-gold-123456789012", false]
    }
    error_message = "Silver e gold devem seguir a convenção de nomes e não ser versionadas (o Iceberg já guarda snapshots)."
  }

  assert {
    condition     = length(aws_ssm_parameter.contract) == 8
    error_message = "Com as três camadas, o contrato deve ter 8 parâmetros."
  }
}

# --- Validações --------------------------------------------------------------

run "rejeita_camada_desconhecida" {
  command = plan

  variables {
    layers = ["bronze", "platinum"]
  }

  expect_failures = [var.layers]
}

run "exige_o_bronze" {
  command = plan

  variables {
    layers = ["silver"]
  }

  expect_failures = [var.layers]
}

run "rejeita_limite_abaixo_do_minimo_do_athena" {
  command = plan

  variables {
    athena_bytes_scanned_cutoff = 1024
  }

  expect_failures = [var.athena_bytes_scanned_cutoff]
}

run "rejeita_armazenamento_nao_implementado" {
  command = plan

  variables {
    layer_storage = {
      bronze = "s3"
      silver = "s3tables"
      gold   = "s3"
    }
  }

  expect_failures = [var.layer_storage]
}
