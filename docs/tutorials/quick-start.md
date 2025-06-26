# Quick Start Guide

Este guia te ajudará a configurar e executar a plataforma de Platform Engineering em minutos.

## Pré-requisitos

### Software Necessário
- [Docker](https://docs.docker.com/get-docker/) 20.10+
- [kubectl](https://kubernetes.io/docs/tasks/tools/) 1.28+
- [Helm](https://helm.sh/docs/intro/install/) 3.13+
- [Terraform](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli) 1.6+
- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) 2.0+

### Contas e Credenciais
- Conta AWS com permissões administrativas
- GitHub/GitLab account
- Cluster Kubernetes (EKS, GKE, ou local com kind/minikube)

## Instalação Rápida

### 1. Clone o Repositório

```bash
git clone https://github.com/nataliagranato/plataform-engineer.git
cd plataform-engineer
```

### 2. Configure Credenciais AWS

```bash
aws configure
# OU
export AWS_ACCESS_KEY_ID="sua-access-key"
export AWS_SECRET_ACCESS_KEY="sua-secret-key"
export AWS_DEFAULT_REGION="us-east-1"
```

### 3. Provisione a Infraestrutura

```bash
cd infrastructure/terraform/environments/dev
terraform init
terraform plan
terraform apply -auto-approve
```

### 4. Configure kubectl

```bash
aws eks update-kubeconfig --region us-east-1 --name platform-engineering-dev
kubectl get nodes
```

### 5. Instale Crossplane

```bash
cd ../../../../infrastructure/crossplane/install
chmod +x install.sh
./install.sh
```

### 6. Configure Credentials do Crossplane

```bash
# Crie arquivo com credenciais AWS
cat > aws-credentials.txt << EOF
[default]
aws_access_key_id = $(aws configure get aws_access_key_id)
aws_secret_access_key = $(aws configure get aws_secret_access_key)
EOF

# Crie secret no Kubernetes
kubectl create secret generic aws-secret \
  -n crossplane-system \
  --from-file=creds=./aws-credentials.txt

# Limpe o arquivo de credenciais
rm aws-credentials.txt
```

### 7. Instale ArgoCD

```bash
kubectl apply -f ../../argocd/install/argocd.yaml
```

### 8. Acesse ArgoCD

```bash
# Obtenha a senha do admin
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# Port-forward para acessar localmente
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Acesse: https://localhost:8080
# Usuário: admin
# Senha: (obtida no comando anterior)
```

### 9. Instale Stack de Observabilidade

```bash
# Prometheus
kubectl apply -f ../../observability/prometheus/prometheus.yaml

# Grafana
kubectl apply -f ../../observability/grafana/grafana.yaml

# Port-forward para Grafana
kubectl port-forward svc/grafana -n monitoring 3000:3000

# Acesse: http://localhost:3000
# Usuário: admin
# Senha: admin123
```

### 10. Configure Backstage (Opcional)

```bash
# Instale Node.js 18+
node --version
npm --version

# Crie app Backstage
npx @backstage/create-app@latest
cd backstage-app

# Configure com os arquivos do repositório
cp ../backstage/config/app-config.yaml app-config.yaml

# Instale dependências e execute
npm install
npm run dev

# Acesse: http://localhost:3000
```

## Verificação da Instalação

### 1. Verifique Crossplane

```bash
kubectl get providers
kubectl get compositeresourcedefinitions
kubectl get compositions
```

### 2. Verifique ArgoCD

```bash
kubectl get applications -n argocd
kubectl get pods -n argocd
```

### 3. Verifique Observabilidade

```bash
kubectl get pods -n monitoring
kubectl get services -n monitoring
```

### 4. Teste Criação de Aplicação

```bash
# Aplique um exemplo de Application Claim
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

# Verifique o status
kubectl get applications
kubectl describe application example-app
```

## Próximos Passos

### Configuração Adicional

1. **Configure HTTPS/TLS**
   ```bash
   # Instale cert-manager
   kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml
   ```

2. **Configure DNS**
   - Configure Route53 ou seu provedor DNS
   - Aponte domínios para Load Balancers

3. **Configure SSO/OIDC**
   - Configure GitHub/Google OAuth
   - Integre com ArgoCD e Grafana

4. **Configure Backup**
   - Configure backup do ETCD
   - Configure backup de bancos de dados

### Desenvolvimento

1. **Crie Templates Personalizados**
   - Defina templates no Backstage
   - Configure pipelines específicos

2. **Defina Policies**
   - Configure OPA/Gatekeeper
   - Defina resource quotas

3. **Configure Alertas**
   - Configure Alertmanager
   - Integre com Slack/Teams

## Troubleshooting

### Problemas Comuns

1. **Crossplane Provider não está Healthy**
   ```bash
   kubectl describe provider provider-aws
   kubectl logs -n crossplane-system deployment/crossplane
   ```

2. **ArgoCD Applications OutOfSync**
   ```bash
   kubectl get applications -n argocd
   # Force sync via UI ou CLI
   argocd app sync APP_NAME
   ```

3. **Prometheus não coleta métricas**
   ```bash
   kubectl logs -n monitoring deployment/prometheus
   kubectl get servicemonitors
   ```

4. **Grafana não conecta ao Prometheus**
   ```bash
   kubectl port-forward svc/prometheus -n monitoring 9090:9090
   # Teste: http://localhost:9090
   ```

### Logs Úteis

```bash
# Crossplane
kubectl logs -n crossplane-system deployment/crossplane

# ArgoCD
kubectl logs -n argocd deployment/argocd-server
kubectl logs -n argocd deployment/argocd-application-controller

# Prometheus
kubectl logs -n monitoring deployment/prometheus

# Grafana
kubectl logs -n monitoring deployment/grafana
```

### Reset Completo

```bash
# CUIDADO: Isso vai deletar tudo!
terraform destroy -auto-approve
kubectl delete namespace argocd monitoring crossplane-system
```

## Suporte

- 📖 [Documentação Completa](../architecture/overview.md)
- 🔧 [Runbooks](../runbooks/)
- 🎓 [Tutorials](../tutorials/)
- 🐛 [Issues no GitHub](https://github.com/nataliagranato/plataform-engineer/issues)

---

**🎉 Parabéns! Sua plataforma está configurada e funcionando.**

Acesse os dashboards:
- ArgoCD: https://localhost:8080
- Grafana: http://localhost:3000
- Prometheus: http://localhost:9090
- Backstage: http://localhost:3000 (se instalado)
