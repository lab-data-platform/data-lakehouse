SHELL := /bin/bash

REPO        := lakehouse
PLATFORM    ?= lab-data
ENV         ?= dev
AWS_PROFILE ?= lab-data
AWS_REGION  ?= us-east-2
export AWS_PROFILE AWS_REGION

# Avaliado só quando usado (=), para não chamar a AWS em todo `make`.
# O $(shell) não herda o `export` do Makefile, por isso o profile vai explícito.
ACCOUNT_ID   = $(shell AWS_PROFILE=$(AWS_PROFILE) aws sts get-caller-identity --query Account --output text)
STATE_BUCKET = $(PLATFORM)-tfstate-$(ACCOUNT_ID)

# Ambiente local: todo comando vai para o moto (ver local/env.sh).
LOCAL := source local/env.sh &&

.DEFAULT_GOAL := help

.PHONY: help whoami fmt validate test init plan apply destroy smoke-test \
        local-up local-test local-down

help: ## Lista os comandos disponíveis
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'

whoami: ## Mostra com qual identidade AWS os comandos vão rodar
	@aws sts get-caller-identity --query Arn --output text

# --- Nível 1: unitário (sem AWS) ---------------------------------------------

fmt: ## Formata o código Terraform
	terraform fmt -recursive .

validate: ## Valida a sintaxe
	terraform -chdir=infra init -backend=false -input=false >/dev/null
	terraform -chdir=infra validate

test: ## Testes unitários (provider simulado, sem AWS)
	terraform -chdir=infra init -backend=false -input=false >/dev/null
	terraform -chdir=infra test

# --- Nível 2: integração local (moto em Docker) ------------------------------

local-up: ## Sobe o moto e simula o contrato do data-foundation
	docker compose -f local/docker-compose.yml up -d --wait
	bash local/seed.sh

local-test: ## Aplica o stack no moto, confere os recursos e destrói
	$(LOCAL) terraform -chdir=infra init -reconfigure -input=false -backend-config=../local/backend.local.hcl >/dev/null
	$(LOCAL) terraform -chdir=infra apply -auto-approve -input=false -var-file=../local/local.tfvars
	bash local/verify.sh
	$(LOCAL) terraform -chdir=infra destroy -auto-approve -input=false -var-file=../local/local.tfvars

local-down: ## Derruba o moto e apaga o estado local
	docker compose -f local/docker-compose.yml down
	rm -rf infra/.terraform-local

# --- Nível 3: conta real -----------------------------------------------------

init: ## Inicializa o stack com o backend remoto no S3
	terraform -chdir=infra init -reconfigure \
		-backend-config="bucket=$(STATE_BUCKET)" \
		-backend-config="key=$(REPO)/$(ENV)/terraform.tfstate" \
		-backend-config="region=$(AWS_REGION)" \
		-backend-config="profile=$(AWS_PROFILE)"

plan: ## Mostra as mudanças
	terraform -chdir=infra plan -var="environment=$(ENV)"

apply: ## Aplica as mudanças
	terraform -chdir=infra apply -var="environment=$(ENV)"

destroy: ## Destrói o stack (apaga os dados dos buckets em dev)
	terraform -chdir=infra destroy -var="environment=$(ENV)"

smoke-test: ## Cria, consulta e apaga uma tabela Iceberg na conta real
	ENV=$(ENV) bash scripts/smoke-test.sh
