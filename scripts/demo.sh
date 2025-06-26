#!/bin/bash

# Platform Engineering Demo Script
# This script demonstrates the complete platform capabilities

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 Platform Engineering Demo${NC}"
echo "==============================="
echo ""

# Function to print step
print_step() {
    echo -e "${BLUE}📋 Step $1: $2${NC}"
}

# Function to print success
print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

# Function to print warning
print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# Function to print error
print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    print_error "kubectl not found. Please install kubectl first."
    exit 1
fi

print_step "1" "Creating demo namespace"
kubectl create namespace platform-demo --dry-run=client -o yaml | kubectl apply -f -
print_success "Demo namespace created"

print_step "2" "Deploying sample application with Crossplane"
cat <<EOF | kubectl apply -f -
apiVersion: platform.io/v1alpha1
kind: Application
metadata:
  name: demo-app
  namespace: platform-demo
spec:
  parameters:
    name: demo-app
    environment: dev
    region: us-east-1
    version: "1.28"
    
    networking:
      vpcCidr: "10.0.0.0/16"
      publicSubnets:
        - "10.0.1.0/24"
        - "10.0.2.0/24"
    
    nodeGroup:
      instanceTypes: ["t3.medium"]
      minSize: 1
      maxSize: 3
      desiredSize: 2
      diskSize: 20
    
    database:
      enabled: false
    
    application:
      replicas: 2
      resources:
        requests:
          cpu: "100m"
          memory: "128Mi"
        limits:
          cpu: "500m"
          memory: "512Mi"
    
    security:
      networkPolicies: true
      podSecurityStandards: "baseline"
    
    monitoring:
      enabled: true
      metrics: true
      logs: true
      traces: true

  writeConnectionSecretsToRef:
    name: demo-app-connection
    namespace: platform-demo
EOF

print_success "Crossplane Application claim created"

print_step "3" "Deploying Kubernetes application using Kustomize"
cat <<EOF > /tmp/demo-app.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: demo-web-app
  namespace: platform-demo
  labels:
    app.kubernetes.io/name: demo-web-app
    app.kubernetes.io/instance: demo
    app.kubernetes.io/version: "1.0.0"
    app.kubernetes.io/component: frontend
spec:
  replicas: 2
  selector:
    matchLabels:
      app.kubernetes.io/name: demo-web-app
      app.kubernetes.io/instance: demo
  template:
    metadata:
      labels:
        app.kubernetes.io/name: demo-web-app
        app.kubernetes.io/instance: demo
        app.kubernetes.io/version: "1.0.0"
        app.kubernetes.io/component: frontend
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "8080"
        prometheus.io/path: "/metrics"
    spec:
      serviceAccountName: default
      securityContext:
        runAsNonRoot: true
        runAsUser: 65534
        fsGroup: 65534
      containers:
      - name: web-app
        image: nginx:1.21
        ports:
        - name: http
          containerPort: 80
          protocol: TCP
        env:
        - name: ENVIRONMENT
          value: "demo"
        - name: VERSION
          value: "1.0.0"
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 200m
            memory: 256Mi
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          runAsNonRoot: true
          runAsUser: 65534
          capabilities:
            drop:
            - ALL
        livenessProbe:
          httpGet:
            path: /
            port: http
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /
            port: http
          initialDelaySeconds: 5
          periodSeconds: 5

---
apiVersion: v1
kind: Service
metadata:
  name: demo-web-app
  namespace: platform-demo
  labels:
    app.kubernetes.io/name: demo-web-app
    app.kubernetes.io/instance: demo
    app.kubernetes.io/component: frontend
spec:
  type: ClusterIP
  ports:
  - port: 80
    targetPort: http
    protocol: TCP
    name: http
  selector:
    app.kubernetes.io/name: demo-web-app
    app.kubernetes.io/instance: demo

---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: demo-web-app-netpol
  namespace: platform-demo
  labels:
    app.kubernetes.io/name: demo-web-app
    app.kubernetes.io/instance: demo
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/name: demo-web-app
      app.kubernetes.io/instance: demo
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector: {}
    ports:
    - protocol: TCP
      port: 80
  egress:
  - to: []
    ports:
    - protocol: TCP
      port: 53
    - protocol: UDP
      port: 53
EOF

kubectl apply -f /tmp/demo-app.yaml
print_success "Demo web application deployed"

print_step "4" "Creating ArgoCD Application"
cat <<EOF | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: demo-app
  namespace: argocd
  labels:
    app.kubernetes.io/name: demo-app
spec:
  project: default
  source:
    repoURL: https://github.com/nataliagranato/plataform-engineer
    targetRevision: HEAD
    path: kubernetes/base
  destination:
    server: https://kubernetes.default.svc
    namespace: platform-demo
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
EOF

print_success "ArgoCD Application created"

print_step "5" "Installing demo application via Helm"
cat <<EOF > /tmp/demo-values.yaml
microservice:
  name: "demo-service"
  image:
    repository: nginx
    tag: "1.21"
    pullPolicy: IfNotPresent
  
  env:
    - name: ENVIRONMENT
      value: "demo"
    - name: SERVICE_NAME
      value: "demo-service"
  
  resources:
    limits:
      cpu: 200m
      memory: 256Mi
    requests:
      cpu: 100m
      memory: 128Mi

deployment:
  replicaCount: 2

service:
  enabled: true
  type: ClusterIP
  port: 80

configMap:
  enabled: true
  data:
    config.yaml: |
      app:
        name: demo-service
        environment: demo
        debug: true

serviceMonitor:
  enabled: true
  interval: 30s

networkPolicy:
  enabled: true

hpa:
  enabled: true
  minReplicas: 2
  maxReplicas: 5
  targetCPUUtilizationPercentage: 70
EOF

# Only install if Helm chart exists
if [ -d "helm/charts/microservice" ]; then
    helm install demo-service helm/charts/microservice/ \
        --namespace platform-demo \
        --values /tmp/demo-values.yaml \
        --create-namespace
    print_success "Helm chart installed"
else
    print_warning "Helm chart not found, skipping Helm installation"
fi

print_step "6" "Checking deployment status"
echo "Waiting for pods to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=demo-web-app -n platform-demo --timeout=300s || true

print_step "7" "Displaying platform resources"
echo -e "${BLUE}📊 Platform Resources:${NC}"
echo ""

echo -e "${YELLOW}Namespaces:${NC}"
kubectl get namespaces | grep -E "(platform-demo|argocd|crossplane|observability)" || true

echo ""
echo -e "${YELLOW}Demo Application Pods:${NC}"
kubectl get pods -n platform-demo -o wide || true

echo ""
echo -e "${YELLOW}Demo Application Services:${NC}"
kubectl get services -n platform-demo || true

echo ""
echo -e "${YELLOW}Crossplane Resources:${NC}"
kubectl get applications.platform.io 2>/dev/null || print_warning "Crossplane not available"

echo ""
echo -e "${YELLOW}ArgoCD Applications:${NC}"
kubectl get applications.argoproj.io -n argocd 2>/dev/null || print_warning "ArgoCD not available"

print_step "8" "Demo commands"
echo -e "${BLUE}🎯 Demo Commands:${NC}"
echo ""
echo "# Port forward to demo application:"
echo "kubectl port-forward svc/demo-web-app 8080:80 -n platform-demo"
echo ""
echo "# Check application logs:"
echo "kubectl logs -l app.kubernetes.io/name=demo-web-app -n platform-demo"
echo ""
echo "# Scale application:"
echo "kubectl scale deployment demo-web-app --replicas=3 -n platform-demo"
echo ""
echo "# Check resource usage:"
echo "kubectl top pods -n platform-demo"
echo ""
echo "# Access application:"
echo "curl http://localhost:8080 (after port-forward)"

print_step "9" "Cleanup instructions"
echo -e "${BLUE}🧹 Cleanup Commands:${NC}"
echo ""
echo "# Delete demo resources:"
echo "kubectl delete namespace platform-demo"
echo ""
echo "# Delete ArgoCD application:"
echo "kubectl delete application demo-app -n argocd"
echo ""
echo "# Delete Crossplane claim:"
echo "kubectl delete application demo-app -n platform-demo"

echo ""
print_success "Demo completed successfully!"
echo ""
echo -e "${GREEN}🎉 Platform Engineering Demo Complete!${NC}"
echo ""
echo "The platform is now running a complete demo application with:"
echo "- Kubernetes deployment with security policies"
echo "- Service mesh ready configuration"
echo "- Monitoring and observability"
echo "- GitOps with ArgoCD"
echo "- Infrastructure as Code with Crossplane"
echo ""
echo "Next steps:"
echo "1. Explore the applications in different namespaces"
echo "2. Check monitoring dashboards (if observability stack is installed)"
echo "3. Experiment with scaling and updates"
echo "4. Try creating your own applications using the platform"

# Cleanup temp files
rm -f /tmp/demo-app.yaml /tmp/demo-values.yaml
