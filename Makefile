SHELL := /bin/bash
.EXPORT_ALL_VARIABLES:

.PHONY: dev-check dev-up dev-down deploy-check prod-deploy package-helm

-include .env
-include .env.dev

NAMESPACE ?= sie
DEPLOY_ENV ?= preprod
RELEASE_DEF_BB_DB ?= sie-definition-blackboard-database

DEF_BB_DB_CHART ?= ops/helm
DEF_BB_DB_ENV_FILE ?= $(DEF_BB_DB_CHART)/environments/$(DEPLOY_ENV)/values.yaml

PORT_FORWARD_PID_FILE ?= .dev-port-forwards.pids

dev-check:
	@command -v kubectl >/dev/null 2>&1 || { echo "Missing required command: kubectl"; exit 1; }
	@command -v helm >/dev/null 2>&1 || { echo "Missing required command: helm"; exit 1; }
	@kubectl config current-context >/dev/null 2>&1 || { echo "No active Kubernetes context. Configure kubeconfig first."; exit 1; }
	@kubectl get ns >/dev/null 2>&1 || { echo "Cannot reach Kubernetes API with current context."; exit 1; }
	@test -d "$(DEF_BB_DB_CHART)" || { echo "Missing chart directory: $(DEF_BB_DB_CHART)"; exit 1; }
	@test -f "$(DEF_BB_DB_CHART)/environments/dev/values.yaml" || { echo "Missing dev values file: $(DEF_BB_DB_CHART)/environments/dev/values.yaml"; exit 1; }
	@echo "dev-check passed"

deploy-check:
	@command -v kubectl >/dev/null 2>&1 || { echo "Missing required command: kubectl"; exit 1; }
	@command -v helm >/dev/null 2>&1 || { echo "Missing required command: helm"; exit 1; }
	@kubectl config current-context >/dev/null 2>&1 || { echo "No active Kubernetes context. Configure kubeconfig first."; exit 1; }
	@kubectl get ns >/dev/null 2>&1 || { echo "Cannot reach Kubernetes API with current context."; exit 1; }
	@test -d "$(DEF_BB_DB_CHART)" || { echo "Missing chart directory: $(DEF_BB_DB_CHART)"; exit 1; }
	@test -f "$(DEF_BB_DB_ENV_FILE)" || { echo "Missing environment values file: $(DEF_BB_DB_ENV_FILE)"; exit 1; }
	@: "$${DB_PASSWORD:?Missing DB_PASSWORD in environment}"
	@echo "deploy-check passed"

dev-up:
	@$(MAKE) dev-check
	@: "$${DB_PASSWORD:?Missing DB_PASSWORD in environment}"
	kubectl get ns $(NAMESPACE) >/dev/null 2>&1 || kubectl create ns $(NAMESPACE) >/dev/null
	helm upgrade --install $(RELEASE_DEF_BB_DB) $(DEF_BB_DB_CHART) -n $(NAMESPACE) --create-namespace --wait --timeout 10m0s \
		-f $(DEF_BB_DB_CHART)/environments/dev/values.yaml \
		--set-string secrets.DB_PASSWORD="$${DB_PASSWORD}"
	@if [[ -f "$(PORT_FORWARD_PID_FILE)" ]]; then \
		xargs -r kill < "$(PORT_FORWARD_PID_FILE)" 2>/dev/null || true; \
		rm -f "$(PORT_FORWARD_PID_FILE)"; \
	fi
	nohup kubectl -n $(NAMESPACE) port-forward svc/$(RELEASE_DEF_BB_DB) 5432:5432 >/tmp/sie-bb-db-pf-postgres.log 2>&1 & echo $$! >> "$(PORT_FORWARD_PID_FILE)"
	@echo "Definition Blackboard Database is ready and port-forward started."

dev-down:
	@if [[ -f "$(PORT_FORWARD_PID_FILE)" ]]; then \
		xargs -r kill < "$(PORT_FORWARD_PID_FILE)" 2>/dev/null || true; \
		rm -f "$(PORT_FORWARD_PID_FILE)"; \
	fi
	helm uninstall $(RELEASE_DEF_BB_DB) -n $(NAMESPACE) || true

prod-deploy:
	@$(MAKE) deploy-check
	helm upgrade --install $(RELEASE_DEF_BB_DB) $(DEF_BB_DB_CHART) -n $(NAMESPACE) --create-namespace --wait --timeout 10m0s \
		-f $(DEF_BB_DB_ENV_FILE) \
		--set-string secrets.DB_PASSWORD="$${DB_PASSWORD}"

package-helm:
	@command -v helm >/dev/null 2>&1 || { echo "Missing required command: helm"; exit 1; }
	@test -d "$(DEF_BB_DB_CHART)" || { echo "Missing chart directory: $(DEF_BB_DB_CHART)"; exit 1; }
	helm package $(DEF_BB_DB_CHART)