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

run "buckets_seguem_a_convencao" {
  command = plan

  assert {
    condition = {
      for k, b in module.layer_bucket : k => b.name
      } == {
      bronze = "lab-data-dev-bronze-123456789012"
      silver = "lab-data-dev-silver-123456789012"
      gold   = "lab-data-dev-gold-123456789012"
    }
    error_message = "Os buckets das camadas devem se chamar <prefixo>-<camada>-<account_id>."
  }

  assert {
    condition     = module.athena_results_bucket.name == "lab-data-dev-athena-results-123456789012"
    error_message = "O bucket de resultados deve se chamar <prefixo>-athena-results-<account_id>."
  }
}

run "so_o_bronze_e_versionado" {
  command = plan

  assert {
    condition     = module.layer_bucket["bronze"].versioning_enabled
    error_message = "O bronze deve ser versionado, para proteger o dado bruto."
  }

  assert {
    condition     = !module.layer_bucket["silver"].versioning_enabled && !module.layer_bucket["gold"].versioning_enabled
    error_message = "Silver e gold não devem ser versionados: o Iceberg já guarda snapshots."
  }
}

run "databases_do_glue_apontam_para_o_bucket_da_camada" {
  command = plan

  assert {
    condition = {
      for k, db in aws_glue_catalog_database.layer : k => [db.name, db.location_uri]
      } == {
      bronze = ["lab_data_dev_bronze", "s3://lab-data-dev-bronze-123456789012/"]
      silver = ["lab_data_dev_silver", "s3://lab-data-dev-silver-123456789012/"]
      gold   = ["lab_data_dev_gold", "s3://lab-data-dev-gold-123456789012/"]
    }
    error_message = "Cada database deve se chamar lab_data_<env>_<camada> e apontar para o bucket da camada."
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
    error_message = "O workgroup deve usar o Athena engine v3 (suporte a Iceberg)."
  }

  assert {
    condition     = aws_athena_workgroup.this.configuration[0].result_configuration[0].output_location == "s3://lab-data-dev-athena-results-123456789012/"
    error_message = "Os resultados devem ir para o bucket athena-results."
  }
}

run "contrato_publica_os_parametros_esperados" {
  command = apply

  assert {
    condition = toset([for p in aws_ssm_parameter.contract : p.name]) == toset([
      "/lab-data/dev/lakehouse/athena_results_bucket",
      "/lab-data/dev/lakehouse/athena_workgroup",
      "/lab-data/dev/lakehouse/bronze_bucket",
      "/lab-data/dev/lakehouse/glue_database_bronze",
      "/lab-data/dev/lakehouse/glue_database_gold",
      "/lab-data/dev/lakehouse/glue_database_silver",
      "/lab-data/dev/lakehouse/gold_bucket",
      "/lab-data/dev/lakehouse/silver_bucket",
    ])
    error_message = "Os parâmetros do contrato mudaram: atualize data-platform/docs/contratos.md."
  }

  assert {
    condition     = aws_ssm_parameter.contract["glue_database_bronze"].value == "lab_data_dev_bronze"
    error_message = "O contrato deve publicar o nome do database do bronze."
  }
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
