#!/bin/bash

# Crossplane Installation Script
# Instala o Crossplane no cluster EKS

set -e

echo "🚀 Instalando Crossplane..."

# Verificar se kubectl está configurado
if ! kubectl cluster-info &> /dev/null; then
    echo "❌ kubectl não está configurado. Configure o acesso ao cluster EKS primeiro."
    exit 1
fi

# Adicionar o repositório Helm do Crossplane
echo "� Adicionando repositório Helm do Crossplane..."
helm repo add crossplane-stable https://charts.crossplane.io/stable
helm repo update

# Criar namespace do Crossplane
echo "🏗️ Criando namespace crossplane-system..."
kubectl create namespace crossplane-system --dry-run=client -o yaml | kubectl apply -f -

# Instalar Crossplane
echo "⚡ Instalando Crossplane via Helm..."
helm upgrade --install crossplane \
  crossplane-stable/crossplane \
  --namespace crossplane-system \
  --create-namespace \
  --wait \
  --timeout 10m \
  --values - <<EOF
args:
  - --debug
  - --enable-composition-revisions
  - --enable-environment-configs

metrics:
  enabled: true

resourcesCrossplane:
  limits:
    cpu: 100m
    memory: 512Mi
  requests:
    cpu: 100m
    memory: 256Mi

resourcesRBACManager:
  limits:
    cpu: 100m
    memory: 512Mi
  requests:
    cpu: 100m
    memory: 256Mi
EOF

# Aguardar o Crossplane estar pronto
echo "⏳ Aguardando Crossplane estar pronto..."
kubectl wait --for=condition=Available deployment/crossplane --namespace crossplane-system --timeout=300s

# Verificar a instalação
echo "✅ Verificando instalação do Crossplane..."
kubectl get pods -n crossplane-system

echo ""
echo "🎉 Crossplane instalado com sucesso!"
echo ""
echo "Próximos passos:"
echo "1. Instalar providers (AWS, Azure, GCP)"
echo "2. Configurar ProviderConfigs"
echo "3. Criar XRDs (Custom Resource Definitions)"
echo "4. Criar Compositions"
  --create-namespace \
  --wait

echo "⏳ Waiting for Crossplane to be ready..."
kubectl wait --for=condition=ready pod -l app=crossplane --namespace=crossplane-system --timeout=300s

echo "✅ Crossplane installed successfully!"

# Install AWS Provider
echo "📦 Installing AWS Provider..."
kubectl apply -f ../providers/provider-aws.yaml

# Wait for provider to be ready
echo "⏳ Waiting for AWS Provider to be ready..."
kubectl wait --for=condition=healthy provider.pkg.crossplane.io/provider-aws --timeout=300s

echo "✅ AWS Provider installed successfully!"

# Create AWS credentials secret if not exists
if ! kubectl get secret aws-secret -n crossplane-system >/dev/null 2>&1; then
  echo "🔐 Please create AWS credentials secret:"
  echo "kubectl create secret generic aws-secret -n crossplane-system --from-file=creds=./aws-credentials.txt"
  echo ""
  echo "aws-credentials.txt should contain:"
  echo "[default]"
  echo "aws_access_key_id = YOUR_ACCESS_KEY"
  echo "aws_secret_access_key = YOUR_SECRET_KEY"
fi

echo "🎉 Crossplane setup completed!"
