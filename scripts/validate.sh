#!/bin/bash

# Script para validar a estrutura do projeto Platform Engineering
# Autor: Platform Engineering Team
# Data: $(date +%Y-%m-%d)

set -e

echo "🔍 Validando estrutura do projeto Platform Engineering..."
echo "=================================================="

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Contador de validações
TOTAL_CHECKS=0
PASSED_CHECKS=0

check_directory() {
    local dir=$1
    local description=$2
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    
    if [ -d "$dir" ]; then
        echo -e "${GREEN}✅ $description${NC}"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
    else
        echo -e "${RED}❌ $description (missing: $dir)${NC}"
    fi
}

check_file() {
    local file=$1
    local description=$2
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    
    if [ -f "$file" ]; then
        echo -e "${GREEN}✅ $description${NC}"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
    else
        echo -e "${RED}❌ $description (missing: $file)${NC}"
    fi
}

echo -e "${YELLOW}📁 Verificando estrutura de diretórios...${NC}"
echo ""

# CI/CD
echo "🔄 CI/CD Pipeline:"
check_directory ".github/workflows" "GitHub Actions workflows"

# Infrastructure
echo ""
echo "🏗️ Infrastructure:"
check_directory "infrastructure/terraform/environments/dev" "Terraform Dev Environment"
check_directory "infrastructure/terraform/environments/staging" "Terraform Staging Environment"
check_directory "infrastructure/terraform/environments/prod" "Terraform Prod Environment"
check_directory "infrastructure/terraform/modules" "Terraform Modules"
check_directory "infrastructure/terraform/shared" "Terraform Shared Resources"

echo ""
echo "⚡ Crossplane:"
check_directory "infrastructure/crossplane/install" "Crossplane Installation"
check_directory "infrastructure/crossplane/providers" "Crossplane Providers"
check_directory "infrastructure/crossplane/compositions" "Crossplane Compositions"
check_directory "infrastructure/crossplane/claims" "Crossplane Claims"

# Kubernetes
echo ""
echo "☸️ Kubernetes:"
check_directory "kubernetes/base" "Kubernetes Base Manifests"
check_directory "kubernetes/overlays" "Kustomize Overlays"
check_directory "kubernetes/operators" "Custom Operators"

# Helm
echo ""
echo "⛵ Helm:"
check_directory "helm/charts" "Helm Charts"
check_directory "helm/values" "Helm Values"

# ArgoCD
echo ""
echo "🔄 ArgoCD GitOps:"
check_directory "argocd/install" "ArgoCD Installation"
check_directory "argocd/applications" "ArgoCD Applications"
check_directory "argocd/projects" "ArgoCD Projects"
check_directory "argocd/repositories" "ArgoCD Repositories"

# Backstage
echo ""
echo "🎭 Backstage Developer Portal:"
check_directory "backstage/catalog" "Service Catalog"
check_directory "backstage/templates" "Software Templates"
check_directory "backstage/plugins" "Custom Plugins"
check_directory "backstage/config" "Backstage Configuration"

# Docker
echo ""
echo "🐳 Docker:"
check_directory "docker/base-images" "Docker Base Images"
check_directory "docker/security" "Docker Security Policies"
check_directory "docker/registries" "Docker Registry Configs"

# Observability
echo ""
echo "� Observability:"
check_directory "observability/prometheus" "Prometheus Monitoring"
check_directory "observability/grafana" "Grafana Dashboards"
check_directory "observability/jaeger" "Jaeger Tracing"
check_directory "observability/fluentd" "FluentD Log Collection"

# Documentation
echo ""
echo "📚 Documentation:"
check_directory "docs/architecture" "Architecture Documentation"
check_directory "docs/runbooks" "Operational Runbooks"
check_directory "docs/tutorials" "Tutorials and Guides"

# Essential files
echo ""
echo "📄 Essential Files:"
check_file "README.md" "Project README"
check_file "Makefile" "Project Makefile"
check_file ".gitignore" "Git ignore file"

# Summary
echo ""
echo "=================================================="
echo -e "${YELLOW}📊 RESUMO DA VALIDAÇÃO${NC}"
echo "=================================================="
echo -e "Total de verificações: ${TOTAL_CHECKS}"
echo -e "Verificações aprovadas: ${GREEN}${PASSED_CHECKS}${NC}"
echo -e "Verificações falharam: ${RED}$((TOTAL_CHECKS - PASSED_CHECKS))${NC}"

if [ $PASSED_CHECKS -eq $TOTAL_CHECKS ]; then
    echo ""
    echo -e "${GREEN}🎉 SUCESSO! Estrutura do projeto está completa!${NC}"
    exit 0
else
    echo ""
    echo -e "${RED}❌ ATENÇÃO! Alguns diretórios/arquivos estão faltando.${NC}"
    echo -e "${YELLOW}💡 Execute os comandos necessários para criar a estrutura completa.${NC}"
    exit 1
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Helper functions
check_command() {
    if command -v "$1" >/dev/null 2>&1; then
        echo -e "${GREEN}✅ $1 is installed${NC}"
        return 0
    else
        echo -e "${RED}❌ $1 is not installed${NC}"
        return 1
    fi
}

check_k8s_resource() {
    local resource_type=$1
    local resource_name=$2
    local namespace=${3:-"default"}
    
    if kubectl get "$resource_type" "$resource_name" -n "$namespace" >/dev/null 2>&1; then
        echo -e "${GREEN}✅ $resource_type/$resource_name exists in $namespace${NC}"
        return 0
    else
        echo -e "${RED}❌ $resource_type/$resource_name not found in $namespace${NC}"
        return 1
    fi
}

check_pod_status() {
    local label_selector=$1
    local namespace=${2:-"default"}
    local expected_status=${3:-"Running"}
    
    local pods=$(kubectl get pods -l "$label_selector" -n "$namespace" -o jsonpath='{.items[*].status.phase}' 2>/dev/null)
    
    if [[ -n "$pods" ]]; then
        local all_running=true
        for status in $pods; do
            if [[ "$status" != "$expected_status" ]]; then
                all_running=false
                break
            fi
        done
        
        if $all_running; then
            echo -e "${GREEN}✅ All pods with label '$label_selector' are $expected_status in $namespace${NC}"
            return 0
        else
            echo -e "${YELLOW}⚠️  Some pods with label '$label_selector' are not $expected_status in $namespace${NC}"
            return 1
        fi
    else
        echo -e "${RED}❌ No pods found with label '$label_selector' in $namespace${NC}"
        return 1
    fi
}

# Start validation
echo "1. Checking Prerequisites"
echo "-------------------------"

PREREQS_OK=true

check_command "kubectl" || PREREQS_OK=false
check_command "helm" || PREREQS_OK=false
check_command "terraform" || PREREQS_OK=false
check_command "aws" || PREREQS_OK=false

if ! $PREREQS_OK; then
    echo -e "${RED}❌ Some prerequisites are missing. Please install them first.${NC}"
    exit 1
fi

echo ""
echo "2. Checking Kubernetes Connectivity"
echo "-----------------------------------"

if kubectl cluster-info >/dev/null 2>&1; then
    echo -e "${GREEN}✅ Connected to Kubernetes cluster${NC}"
    kubectl cluster-info | head -1
else
    echo -e "${RED}❌ Cannot connect to Kubernetes cluster${NC}"
    exit 1
fi

echo ""
echo "3. Checking Crossplane Installation"
echo "-----------------------------------"

CROSSPLANE_OK=true

check_k8s_resource "namespace" "crossplane-system" || CROSSPLANE_OK=false
check_pod_status "app=crossplane" "crossplane-system" || CROSSPLANE_OK=false

# Check providers
if kubectl get providers >/dev/null 2>&1; then
    echo -e "${GREEN}✅ Crossplane providers are configured${NC}"
    kubectl get providers --no-headers | wc -l | xargs echo "   Found providers:"
else
    echo -e "${YELLOW}⚠️  No Crossplane providers found${NC}"
    CROSSPLANE_OK=false
fi

# Check XRDs
if kubectl get xrds >/dev/null 2>&1; then
    local xrd_count=$(kubectl get xrds --no-headers | wc -l)
    if [ "$xrd_count" -gt 0 ]; then
        echo -e "${GREEN}✅ Found $xrd_count XRDs${NC}"
    else
        echo -e "${YELLOW}⚠️  No XRDs found${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  Cannot check XRDs${NC}"
fi

echo ""
echo "4. Checking ArgoCD Installation"
echo "-------------------------------"

ARGOCD_OK=true

check_k8s_resource "namespace" "argocd" || ARGOCD_OK=false
check_pod_status "app.kubernetes.io/name=argocd-server" "argocd" || ARGOCD_OK=false

# Check ArgoCD applications
if kubectl get applications -n argocd >/dev/null 2>&1; then
    local app_count=$(kubectl get applications -n argocd --no-headers | wc -l)
    if [ "$app_count" -gt 0 ]; then
        echo -e "${GREEN}✅ Found $app_count ArgoCD applications${NC}"
    else
        echo -e "${YELLOW}⚠️  No ArgoCD applications found${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  Cannot check ArgoCD applications${NC}"
fi

echo ""
echo "5. Checking Monitoring Stack"
echo "----------------------------"

MONITORING_OK=true

check_k8s_resource "namespace" "monitoring" || MONITORING_OK=false
check_pod_status "app=prometheus" "monitoring" || MONITORING_OK=false
check_pod_status "app=grafana" "monitoring" || MONITORING_OK=false

echo ""
echo "6. Checking Terraform Configuration"
echo "-----------------------------------"

TERRAFORM_OK=true

if [ -d "infrastructure/terraform/environments/dev" ]; then
    cd infrastructure/terraform/environments/dev
    
    # Check if terraform is initialized
    if [ -d ".terraform" ]; then
        echo -e "${GREEN}✅ Terraform is initialized${NC}"
    else
        echo -e "${YELLOW}⚠️  Terraform is not initialized. Run 'terraform init'${NC}"
        TERRAFORM_OK=false
    fi
    
    # Validate terraform configuration
    if terraform validate >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Terraform configuration is valid${NC}"
    else
        echo -e "${RED}❌ Terraform configuration is invalid${NC}"
        terraform validate
        TERRAFORM_OK=false
    fi
    
    cd - >/dev/null
else
    echo -e "${RED}❌ Terraform environment directory not found${NC}"
    TERRAFORM_OK=false
fi

echo ""
echo "7. Testing Example Application Deployment"
echo "-----------------------------------------"

EXAMPLE_OK=true

# Try to apply an example application claim
if kubectl apply --dry-run=client -f infrastructure/crossplane/claims/examples.yaml >/dev/null 2>&1; then
    echo -e "${GREEN}✅ Example application claims are valid${NC}"
else
    echo -e "${RED}❌ Example application claims are invalid${NC}"
    EXAMPLE_OK=false
fi

echo ""
echo "8. Summary"
echo "----------"

ALL_OK=true

echo "Component Status:"
$PREREQS_OK && echo -e "${GREEN}✅ Prerequisites${NC}" || { echo -e "${RED}❌ Prerequisites${NC}"; ALL_OK=false; }
echo -e "${GREEN}✅ Kubernetes Connectivity${NC}"
$CROSSPLANE_OK && echo -e "${GREEN}✅ Crossplane${NC}" || { echo -e "${RED}❌ Crossplane${NC}"; ALL_OK=false; }
$ARGOCD_OK && echo -e "${GREEN}✅ ArgoCD${NC}" || { echo -e "${RED}❌ ArgoCD${NC}"; ALL_OK=false; }
$MONITORING_OK && echo -e "${GREEN}✅ Monitoring${NC}" || { echo -e "${RED}❌ Monitoring${NC}"; ALL_OK=false; }
$TERRAFORM_OK && echo -e "${GREEN}✅ Terraform${NC}" || { echo -e "${RED}❌ Terraform${NC}"; ALL_OK=false; }
$EXAMPLE_OK && echo -e "${GREEN}✅ Examples${NC}" || { echo -e "${RED}❌ Examples${NC}"; ALL_OK=false; }

echo ""

if $ALL_OK; then
    echo -e "${GREEN}🎉 All validation checks passed!${NC}"
    echo -e "${GREEN}Your Platform Engineering setup is ready to use.${NC}"
    echo ""
    echo "Next steps:"
    echo "- Access ArgoCD: kubectl port-forward svc/argocd-server -n argocd 8080:443"
    echo "- Access Grafana: kubectl port-forward svc/grafana -n monitoring 3000:3000"
    echo "- Deploy example app: kubectl apply -f infrastructure/crossplane/claims/examples.yaml"
    exit 0
else
    echo -e "${RED}❌ Some validation checks failed.${NC}"
    echo -e "${YELLOW}Please review the issues above and fix them before proceeding.${NC}"
    echo ""
    echo "Common fixes:"
    echo "- Install missing prerequisites"
    echo "- Run 'make setup' for complete installation"
    echo "- Check 'docs/tutorials/quick-start.md' for detailed instructions"
    exit 1
fi
