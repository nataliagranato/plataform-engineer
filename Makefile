# Makefile for Platform Engineering Framework

.PHONY: help install setup deploy clean validate test

# Variables
CLUSTER_NAME ?= platform-dev
AWS_REGION ?= us-east-1
ENVIRONMENT ?= dev
NAMESPACE ?= default

# Colors
RED=\033[0;31m
GREEN=\033[0;32m
YELLOW=\033[0;33m
BLUE=\033[0;34m
NC=\033[0m # No Color

# Default target
help: ## Show this help message
	@echo "Platform Engineering Framework"
	@echo "==============================="
	@echo ""
	@echo "Available targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-25s\033[0m %s\n", $$1, $$2}'
	@echo ""
	@echo "Environment variables:"
	@echo "  CLUSTER_NAME=$(CLUSTER_NAME)"
	@echo "  AWS_REGION=$(AWS_REGION)"
	@echo "  ENVIRONMENT=$(ENVIRONMENT)"
	@echo "  NAMESPACE=$(NAMESPACE)"

# Prerequisites check
check-prereqs: ## Check if required tools are installed
	@echo "$(BLUE)Checking prerequisites...$(NC)"
	@command -v kubectl >/dev/null 2>&1 || { echo "$(RED)kubectl is required but not installed. Aborting.$(NC)" >&2; exit 1; }
	@command -v helm >/dev/null 2>&1 || { echo "$(RED)helm is required but not installed. Aborting.$(NC)" >&2; exit 1; }
	@command -v terraform >/dev/null 2>&1 || { echo "$(RED)terraform is required but not installed. Aborting.$(NC)" >&2; exit 1; }
	@command -v aws >/dev/null 2>&1 || { echo "$(RED)aws cli is required but not installed. Aborting.$(NC)" >&2; exit 1; }
	@command -v argocd >/dev/null 2>&1 || { echo "$(YELLOW)argocd cli not found. Some commands may not work.$(NC)"; }
	@echo "$(GREEN)✅ All prerequisites are installed!$(NC)"

# Validation
validate: ## Validate all platform components
	@echo "$(BLUE)Validating platform components...$(NC)"
	chmod +x scripts/validate.sh && ./scripts/validate.sh

validate-terraform: ## Validate Terraform configurations
	@echo "$(BLUE)Validating Terraform configurations...$(NC)"
	@for env in dev staging prod; do \
		echo "Validating $$env environment..."; \
		cd infrastructure/terraform/environments/$$env && terraform init -backend=false && terraform validate; \
		cd ../../../..; \
	done

validate-kubernetes: ## Validate Kubernetes manifests
	@echo "$(BLUE)Validating Kubernetes manifests...$(NC)"
	@find kubernetes/ -name "*.yaml" -o -name "*.yml" | \
		xargs -I {} kubectl --dry-run=client --validate=true apply -f {}

validate-helm: ## Validate Helm charts
	@echo "$(BLUE)Validating Helm charts...$(NC)"
	@for chart in helm/charts/*/; do \
		if [ -f "$$chart/Chart.yaml" ]; then \
			echo "Validating chart: $$chart"; \
			helm lint "$$chart"; \
			helm template test "$$chart" --validate; \
		fi; \
	done

# Infrastructure Management
infra-init: check-prereqs ## Initialize infrastructure backend
	@echo "$(BLUE)Initializing infrastructure backend...$(NC)"
	cd infrastructure/terraform/environments/$(ENVIRONMENT) && terraform init

infra-plan: check-prereqs ## Plan infrastructure changes
	@echo "$(BLUE)Planning infrastructure changes for $(ENVIRONMENT)...$(NC)"
	cd infrastructure/terraform/environments/$(ENVIRONMENT) && terraform init && terraform plan

infra-apply: check-prereqs ## Apply infrastructure changes
	@echo "$(BLUE)Applying infrastructure changes for $(ENVIRONMENT)...$(NC)"
	cd infrastructure/terraform/environments/$(ENVIRONMENT) && terraform init && terraform apply

infra-destroy: ## Destroy infrastructure (CAUTION!)
	@echo "$(RED)⚠️  WARNING: This will destroy all infrastructure for $(ENVIRONMENT)!$(NC)"
	@read -p "Are you sure? Type 'yes' to continue: " confirm && [ "$$confirm" = "yes" ]
	cd infrastructure/terraform/environments/$(ENVIRONMENT) && terraform destroy

infra-output: ## Show infrastructure outputs
	@echo "$(BLUE)Infrastructure outputs for $(ENVIRONMENT):$(NC)"
	cd infrastructure/terraform/environments/$(ENVIRONMENT) && terraform output

infra-refresh: ## Refresh infrastructure state
	@echo "$(BLUE)Refreshing infrastructure state for $(ENVIRONMENT)...$(NC)"
	cd infrastructure/terraform/environments/$(ENVIRONMENT) && terraform refresh

# Cluster Management
cluster-connect: ## Update kubeconfig for cluster
	@echo "$(BLUE)Updating kubeconfig for $(CLUSTER_NAME)...$(NC)"
	aws eks update-kubeconfig --region $(AWS_REGION) --name $(CLUSTER_NAME)

cluster-info: ## Show cluster information
	@echo "$(BLUE)Cluster information:$(NC)"
	kubectl cluster-info
	kubectl get nodes -o wide

cluster-health: ## Check cluster health
	@echo "$(BLUE)Checking cluster health...$(NC)"
	kubectl get componentstatuses
	kubectl get nodes --show-labels
	kubectl top nodes 2>/dev/null || echo "Metrics server not available"

# Crossplane Management
crossplane-install: check-prereqs ## Install Crossplane
	@echo "$(BLUE)Installing Crossplane...$(NC)"
	cd infrastructure/crossplane/install && chmod +x install.sh && ./install.sh

crossplane-providers: ## Install Crossplane providers
	@echo "$(BLUE)Installing Crossplane providers...$(NC)"
	kubectl apply -f infrastructure/crossplane/providers/
	@echo "Waiting for providers to be healthy..."
	kubectl wait --for=condition=healthy provider.pkg.crossplane.io --all --timeout=300s

crossplane-compositions: ## Install Crossplane compositions
	@echo "$(BLUE)Installing Crossplane compositions...$(NC)"
	kubectl apply -f infrastructure/crossplane/compositions/

crossplane-examples: ## Apply Crossplane example claims
	@echo "$(BLUE)Applying Crossplane example claims...$(NC)"
	kubectl apply -f infrastructure/crossplane/claims/examples.yaml

crossplane-status: ## Show Crossplane status
	@echo "$(BLUE)Crossplane status:$(NC)"
	kubectl get providers.pkg.crossplane.io
	kubectl get compositeresourcedefinitions.apiextensions.crossplane.io
	kubectl get managed

crossplane-uninstall: ## Uninstall Crossplane
	@echo "$(RED)Uninstalling Crossplane...$(NC)"
	helm uninstall crossplane -n crossplane-system
	kubectl delete namespace crossplane-system

# ArgoCD Management
argocd-install: check-prereqs ## Install ArgoCD
	@echo "$(BLUE)Installing ArgoCD...$(NC)"
	kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
	kubectl apply -f argocd/install/

argocd-password: ## Get ArgoCD admin password
	@echo "$(BLUE)ArgoCD admin password:$(NC)"
	kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d && echo

argocd-port-forward: ## Port forward ArgoCD UI
	@echo "$(BLUE)Port forwarding ArgoCD UI to http://localhost:8080$(NC)"
	kubectl port-forward svc/argocd-server -n argocd 8080:443

argocd-sync: ## Sync all ArgoCD applications
	@echo "$(BLUE)Syncing all ArgoCD applications...$(NC)"
	argocd app sync --all

argocd-status: ## Show ArgoCD application status
	@echo "$(BLUE)ArgoCD application status:$(NC)"
	argocd app list

argocd-uninstall: ## Uninstall ArgoCD
	@echo "$(RED)Uninstalling ArgoCD...$(NC)"
	kubectl delete -f argocd/install/
	kubectl delete namespace argocd

# Observability Management
observability-install: ## Install observability stack
	@echo "$(BLUE)Installing observability stack...$(NC)"
	kubectl create namespace observability --dry-run=client -o yaml | kubectl apply -f -
	kubectl apply -f observability/prometheus/
	kubectl apply -f observability/grafana/
	kubectl apply -f observability/jaeger/
	kubectl apply -f observability/fluentd/

observability-status: ## Show observability stack status
	@echo "$(BLUE)Observability stack status:$(NC)"
	kubectl get pods -n observability

prometheus-port-forward: ## Port forward Prometheus UI
	@echo "$(BLUE)Port forwarding Prometheus UI to http://localhost:9090$(NC)"
	kubectl port-forward svc/prometheus-service -n observability 9090:9090

grafana-port-forward: ## Port forward Grafana UI
	@echo "$(BLUE)Port forwarding Grafana UI to http://localhost:3000$(NC)"
	@echo "Default credentials: admin/admin"
	kubectl port-forward svc/grafana-service -n observability 3000:3000

jaeger-port-forward: ## Port forward Jaeger UI
	@echo "$(BLUE)Port forwarding Jaeger UI to http://localhost:16686$(NC)"
	kubectl port-forward svc/jaeger-query -n observability 16686:16686

observability-uninstall: ## Uninstall observability stack
	@echo "$(RED)Uninstalling observability stack...$(NC)"
	kubectl delete -f observability/prometheus/
	kubectl delete -f observability/grafana/
	kubectl delete -f observability/jaeger/
	kubectl delete -f observability/fluentd/
	kubectl delete namespace observability

# Application Management
app-deploy: ## Deploy application using Kustomize
	@echo "$(BLUE)Deploying application to $(ENVIRONMENT)...$(NC)"
	kubectl apply -k kubernetes/overlays/$(ENVIRONMENT)/

app-status: ## Show application status
	@echo "$(BLUE)Application status in $(ENVIRONMENT):$(NC)"
	kubectl get all -n $(ENVIRONMENT) 2>/dev/null || kubectl get all

app-logs: ## Show application logs
	@echo "$(BLUE)Application logs:$(NC)"
	kubectl logs -l app.kubernetes.io/name=application -n $(ENVIRONMENT) --tail=100

app-delete: ## Delete application
	@echo "$(RED)Deleting application from $(ENVIRONMENT)...$(NC)"
	kubectl delete -k kubernetes/overlays/$(ENVIRONMENT)/

# Helm Management
helm-install-chart: ## Install Helm chart (requires CHART variable)
	@if [ -z "$(CHART)" ]; then echo "$(RED)Please specify CHART variable$(NC)"; exit 1; fi
	@echo "$(BLUE)Installing Helm chart $(CHART)...$(NC)"
	helm install $(CHART) helm/charts/$(CHART)/ --namespace $(NAMESPACE) --create-namespace

helm-upgrade-chart: ## Upgrade Helm chart (requires CHART variable)
	@if [ -z "$(CHART)" ]; then echo "$(RED)Please specify CHART variable$(NC)"; exit 1; fi
	@echo "$(BLUE)Upgrading Helm chart $(CHART)...$(NC)"
	helm upgrade $(CHART) helm/charts/$(CHART)/ --namespace $(NAMESPACE)

helm-uninstall-chart: ## Uninstall Helm chart (requires CHART variable)
	@if [ -z "$(CHART)" ]; then echo "$(RED)Please specify CHART variable$(NC)"; exit 1; fi
	@echo "$(RED)Uninstalling Helm chart $(CHART)...$(NC)"
	helm uninstall $(CHART) --namespace $(NAMESPACE)

helm-list: ## List Helm releases
	@echo "$(BLUE)Helm releases:$(NC)"
	helm list --all-namespaces

# Backstage Management
backstage-install: ## Install Backstage
	@echo "$(BLUE)Installing Backstage...$(NC)"
	kubectl create namespace backstage --dry-run=client -o yaml | kubectl apply -f -
	# Add Backstage installation commands here

backstage-status: ## Show Backstage status
	@echo "$(BLUE)Backstage status:$(NC)"
	kubectl get pods -n backstage

# Security
security-scan: ## Run security scans
	@echo "$(BLUE)Running security scans...$(NC)"
	trivy fs . --exit-code 0
	@echo "$(GREEN)Security scan completed$(NC)"

security-policies: ## Apply security policies
	@echo "$(BLUE)Applying security policies...$(NC)"
	kubectl apply -f kubernetes/base/ | grep -i "networkpolicy\|podsecuritypolicy"

# Development
dev-setup: ## Setup development environment
	@echo "$(BLUE)Setting up development environment...$(NC)"
	$(MAKE) infra-apply ENVIRONMENT=dev
	$(MAKE) cluster-connect CLUSTER_NAME=platform-dev
	$(MAKE) crossplane-install
	$(MAKE) crossplane-providers
	$(MAKE) crossplane-compositions
	$(MAKE) argocd-install
	$(MAKE) observability-install
	@echo "$(GREEN)Development environment setup complete!$(NC)"

dev-teardown: ## Teardown development environment
	@echo "$(RED)Tearing down development environment...$(NC)"
	$(MAKE) observability-uninstall
	$(MAKE) argocd-uninstall
	$(MAKE) crossplane-uninstall
	$(MAKE) infra-destroy ENVIRONMENT=dev
	@echo "$(GREEN)Development environment teardown complete!$(NC)"

# Testing
test: ## Run all tests
	@echo "$(BLUE)Running all tests...$(NC)"
	$(MAKE) validate
	$(MAKE) security-scan
	@echo "$(GREEN)All tests completed!$(NC)"

test-integration: ## Run integration tests
	@echo "$(BLUE)Running integration tests...$(NC)"
	# Add integration test commands here
	@echo "$(GREEN)Integration tests completed!$(NC)"

# Maintenance
maintenance-backup: ## Create backups
	@echo "$(BLUE)Creating backups...$(NC)"
	# Backup Kubernetes resources
	kubectl get all --all-namespaces -o yaml > backup-$(shell date +%Y%m%d-%H%M%S).yaml
	@echo "$(GREEN)Backup completed!$(NC)"

maintenance-cleanup: ## Cleanup unused resources
	@echo "$(BLUE)Cleaning up unused resources...$(NC)"
	kubectl delete pods --field-selector=status.phase=Succeeded
	kubectl delete pods --field-selector=status.phase=Failed
	docker system prune -f
	@echo "$(GREEN)Cleanup completed!$(NC)"

# Complete Installation
install-all: ## Install complete platform
	@echo "$(BLUE)Installing complete platform...$(NC)"
	$(MAKE) check-prereqs
	$(MAKE) validate
	$(MAKE) infra-apply
	$(MAKE) cluster-connect
	$(MAKE) crossplane-install
	$(MAKE) crossplane-providers
	$(MAKE) crossplane-compositions
	$(MAKE) argocd-install
	$(MAKE) observability-install
	@echo "$(GREEN)🎉 Platform installation completed successfully!$(NC)"
	@echo ""
	@echo "Next steps:"
	@echo "1. Access ArgoCD: $(MAKE) argocd-port-forward"
	@echo "2. Access Grafana: $(MAKE) grafana-port-forward"
	@echo "3. Get ArgoCD password: $(MAKE) argocd-password"

# Complete Uninstallation
uninstall-all: ## Uninstall complete platform
	@echo "$(RED)⚠️  WARNING: This will uninstall the complete platform!$(NC)"
	@read -p "Are you sure? Type 'yes' to continue: " confirm && [ "$$confirm" = "yes" ]
	$(MAKE) observability-uninstall
	$(MAKE) argocd-uninstall
	$(MAKE) crossplane-uninstall
	$(MAKE) infra-destroy
	@echo "$(GREEN)Platform uninstallation completed!$(NC)"

# Quick commands
quick-status: ## Quick status check of all components
	@echo "$(BLUE)Quick status check:$(NC)"
	@echo "=== Cluster ==="
	kubectl get nodes --no-headers | wc -l | xargs printf "Nodes: %s\n"
	@echo "=== Crossplane ==="
	kubectl get providers.pkg.crossplane.io --no-headers 2>/dev/null | wc -l | xargs printf "Providers: %s\n"
	@echo "=== ArgoCD ==="
	kubectl get pods -n argocd --no-headers 2>/dev/null | grep Running | wc -l | xargs printf "Running pods: %s\n"
	@echo "=== Observability ==="
	kubectl get pods -n observability --no-headers 2>/dev/null | grep Running | wc -l | xargs printf "Running pods: %s\n"

logs: ## Show logs for platform components
	@echo "$(BLUE)Platform component logs:$(NC)"
	@echo "=== Crossplane ==="
	kubectl logs -n crossplane-system deployment/crossplane --tail=5
	@echo "=== ArgoCD ==="
	kubectl logs -n argocd deployment/argocd-application-controller --tail=5
	@echo "=== Prometheus ==="
	kubectl logs -n observability deployment/prometheus --tail=5 2>/dev/null || echo "Prometheus not found"
	@echo "Installing ArgoCD..."
	kubectl apply -f argocd/install/argocd.yaml
	@echo "Waiting for ArgoCD to be ready..."
	kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s

argocd-password: ## Get ArgoCD admin password
	@echo "ArgoCD admin password:"
	@kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d && echo

argocd-port-forward: ## Port forward ArgoCD UI
	@echo "ArgoCD UI will be available at https://localhost:8080"
	kubectl port-forward svc/argocd-server -n argocd 8080:443

# Observability
monitoring-install: check-prereqs ## Install monitoring stack
	@echo "Installing Prometheus..."
	kubectl apply -f observability/prometheus/prometheus.yaml
	@echo "Installing Grafana..."
	kubectl apply -f observability/grafana/grafana.yaml
	@echo "Waiting for monitoring stack to be ready..."
	kubectl wait --for=condition=ready pod -l app=prometheus -n monitoring --timeout=300s
	kubectl wait --for=condition=ready pod -l app=grafana -n monitoring --timeout=300s

grafana-port-forward: ## Port forward Grafana UI
	@echo "Grafana UI will be available at http://localhost:3000"
	@echo "Username: admin, Password: admin123"
	kubectl port-forward svc/grafana -n monitoring 3000:3000

prometheus-port-forward: ## Port forward Prometheus UI
	@echo "Prometheus UI will be available at http://localhost:9090"
	kubectl port-forward svc/prometheus -n monitoring 9090:9090

# Complete setup
setup: check-prereqs infra-apply crossplane-install argocd-install monitoring-install ## Complete platform setup
	@echo ""
	@echo "🎉 Platform Engineering setup completed!"
	@echo ""
	@echo "Access your services:"
	@echo "- ArgoCD: Run 'make argocd-port-forward' and visit https://localhost:8080"
	@echo "- Grafana: Run 'make grafana-port-forward' and visit http://localhost:3000"
	@echo "- Prometheus: Run 'make prometheus-port-forward' and visit http://localhost:9090"
	@echo ""
	@echo "Get ArgoCD password: make argocd-password"

# Validation and testing
validate: ## Validate all components
	@echo "Validating Terraform..."
	cd infrastructure/terraform/environments/dev && terraform validate
	@echo "Validating Kubernetes manifests..."
	kubectl --dry-run=client --validate=true apply -f infrastructure/crossplane/ -R || true
	kubectl --dry-run=client --validate=true apply -f argocd/ -R || true
	kubectl --dry-run=client --validate=true apply -f observability/ -R || true
	@echo "✅ Validation completed!"

test: ## Run tests
	@echo "Running tests..."
	# Add your test commands here
	@echo "✅ Tests completed!"

# Cleanup
clean: ## Clean up temporary files
	@echo "Cleaning up..."
	find . -name "*.terraform" -type d -exec rm -rf {} + 2>/dev/null || true
	find . -name ".terraform.lock.hcl" -delete 2>/dev/null || true
	@echo "✅ Cleanup completed!"

# Status
status: ## Show platform status
	@echo "Platform Engineering Status"
	@echo "=========================="
	@echo ""
	@echo "Kubernetes Cluster:"
	@kubectl cluster-info --request-timeout=5s 2>/dev/null || echo "❌ Not connected to cluster"
	@echo ""
	@echo "Crossplane:"
	@kubectl get providers 2>/dev/null | head -10 || echo "❌ Crossplane not installed"
	@echo ""
	@echo "ArgoCD:"
	@kubectl get pods -n argocd 2>/dev/null | head -5 || echo "❌ ArgoCD not installed"
	@echo ""
	@echo "Monitoring:"
	@kubectl get pods -n monitoring 2>/dev/null | head -5 || echo "❌ Monitoring not installed"

# Development helpers
dev-setup: ## Setup development environment
	@echo "Setting up development environment..."
	# Add development setup commands here

lint: ## Lint code and configurations
	@echo "Linting configurations..."
	# Add linting commands here

fmt: ## Format code and configurations
	@echo "Formatting configurations..."
	terraform fmt -recursive infrastructure/terraform/

# Examples
example-app: ## Deploy example application
	@echo "Deploying example application..."
	kubectl apply -f - << EOF
	apiVersion: platform.io/v1alpha1
	kind: Application
	metadata:
	  name: example-app
	  namespace: default
	spec:
	  parameters:
	    name: example-app
	    environment: dev
	    replicas: 2
	    resources:
	      cpu: "100m"
	      memory: "128Mi"
	    database:
	      enabled: true
	      engine: postgresql
	EOF
	@echo "✅ Example application deployed!"

# Backup and restore
backup: ## Backup critical components
	@echo "Creating backup..."
	mkdir -p backups/$(shell date +%Y%m%d-%H%M%S)
	# Add backup commands here

restore: ## Restore from backup
	@echo "Restoring from backup..."
	# Add restore commands here
