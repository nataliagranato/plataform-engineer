# Platform Engineering Runbook

## Emergency Response Procedures

### 🚨 Incident Response

#### Severity Levels

| Severity | Impact | Response Time | Examples |
|----------|--------|---------------|----------|
| **P0** | Platform Down | 15 minutes | Complete platform outage, data loss |
| **P1** | Critical Features | 1 hour | Core services unavailable, security breach |
| **P2** | Major Impact | 4 hours | Significant performance degradation |
| **P3** | Minor Impact | 24 hours | Non-critical feature issues |

#### Incident Response Process

1. **Detection**
   ```bash
   # Check overall platform health
   kubectl get nodes
   kubectl get pods --all-namespaces | grep -v Running
   
   # Check critical services
   kubectl get pods -n argocd
   kubectl get pods -n crossplane-system
   kubectl get pods -n observability
   ```

2. **Assessment**
   ```bash
   # Check ArgoCD applications
   kubectl get applications -n argocd
   
   # Check Crossplane providers
   kubectl get providers.pkg.crossplane.io
   
   # Check infrastructure resources
   kubectl get managed -o wide
   ```

3. **Communication**
   - Create incident channel: `#incident-YYYY-MM-DD-HH-MM`
   - Notify stakeholders via PagerDuty/Slack
   - Update status page

4. **Resolution**
   - Follow specific runbooks below
   - Document actions taken
   - Communicate resolution

5. **Post-Incident**
   - Conduct post-mortem within 48 hours
   - Update runbooks
   - Implement preventive measures

---

## 🔧 Operational Procedures

### Cluster Operations

#### EKS Cluster Health Check
```bash
#!/bin/bash
# cluster-health-check.sh

echo "=== EKS Cluster Health Check ==="

# Check cluster status
aws eks describe-cluster --name platform-prod --query 'cluster.status'

# Check node groups
aws eks describe-nodegroup --cluster-name platform-prod --nodegroup-name main

# Check nodes
kubectl get nodes -o wide

# Check critical namespaces
for ns in kube-system crossplane-system argocd observability; do
    echo "=== Namespace: $ns ==="
    kubectl get pods -n $ns | grep -v Running | grep -v Completed
done

# Check resource utilization
kubectl top nodes
kubectl top pods --all-namespaces --sort-by=cpu
```

#### Node Troubleshooting
```bash
# Check node conditions
kubectl describe node <node-name>

# Check node logs
kubectl logs -n kube-system -l k8s-app=aws-node

# Drain node for maintenance
kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data

# Uncordon node after maintenance
kubectl uncordon <node-name>
```

### Crossplane Operations

#### Provider Management
```bash
# Check provider health
kubectl get providers.pkg.crossplane.io

# Check provider logs
kubectl logs -n crossplane-system deployment/crossplane-provider-aws

# Restart provider
kubectl rollout restart deployment/crossplane-provider-aws -n crossplane-system

# Check provider configuration
kubectl get providerconfigs.aws.crossplane.io
```

#### Resource Troubleshooting
```bash
# Check managed resources
kubectl get managed

# Check resource status
kubectl describe <managed-resource-type> <resource-name>

# Check resource events
kubectl get events --sort-by='.lastTimestamp' | grep <resource-name>

# Delete stuck resources
kubectl patch <resource-type> <resource-name> -p '{"metadata":{"finalizers":[]}}' --type=merge
```

### ArgoCD Operations

#### Application Management
```bash
# Check application status
argocd app list

# Sync application
argocd app sync <app-name>

# Force sync with replace
argocd app sync <app-name> --force --replace

# Get application details
argocd app get <app-name>

# Check application logs
kubectl logs -n argocd deployment/argocd-application-controller
```

#### Repository Issues
```bash
# Refresh repository
argocd repo list
argocd repo get <repo-url>

# Force refresh
argocd app refresh <app-name> --hard

# Check repository credentials
kubectl get secrets -n argocd -l argocd.argoproj.io/secret-type=repository
```

### Database Operations

#### RDS Troubleshooting
```bash
# Check RDS instance status
aws rds describe-db-instances --db-instance-identifier platform-prod-db

# Check RDS logs
aws rds describe-db-log-files --db-instance-identifier platform-prod-db
aws rds download-db-log-file-portion --db-instance-identifier platform-prod-db --log-file-name error/postgresql.log.2024-01-01-12

# Create RDS snapshot
aws rds create-db-snapshot --db-instance-identifier platform-prod-db --db-snapshot-identifier platform-prod-snapshot-$(date +%Y%m%d%H%M%S)
```

#### Database Connection Issues
```bash
# Test database connectivity from pod
kubectl run -it --rm debug --image=postgres:15 --restart=Never -- psql -h <db-host> -U <username> -d <database>

# Check connection pool status
kubectl exec -it <app-pod> -- /app/check-db-connections.sh

# Reset connection pool
kubectl rollout restart deployment/<app-name>
```

---

## 📊 Monitoring and Alerting

### Prometheus Queries

#### Infrastructure Metrics
```promql
# Node CPU usage
100 - (avg(irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# Node memory usage
(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100

# Pod CPU usage
rate(container_cpu_usage_seconds_total[5m]) * 100

# Pod memory usage
container_memory_working_set_bytes / container_spec_memory_limit_bytes * 100

# Disk usage
(1 - (node_filesystem_avail_bytes / node_filesystem_size_bytes)) * 100
```

#### Application Metrics
```promql
# Request rate
rate(http_requests_total[5m])

# Error rate
rate(http_requests_total{status=~"5.."}[5m]) / rate(http_requests_total[5m]) * 100

# Response time (95th percentile)
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))

# Database connection pool
db_connection_pool_active / db_connection_pool_max * 100
```

### Grafana Dashboard URLs

- **Cluster Overview**: `https://grafana.platform.com/d/cluster-overview`
- **Node Metrics**: `https://grafana.platform.com/d/node-metrics`
- **Application Metrics**: `https://grafana.platform.com/d/app-metrics`
- **Database Metrics**: `https://grafana.platform.com/d/db-metrics`

### Alert Escalation

#### Alert Routing
```yaml
# Alertmanager configuration
route:
  group_by: ['alertname']
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 1h
  receiver: 'platform-team'
  routes:
  - match:
      severity: critical
    receiver: 'platform-oncall'
  - match:
      severity: warning
    receiver: 'platform-team'
```

---

## 🔐 Security Operations

### Certificate Management
```bash
# Check certificate expiration
kubectl get certificates --all-namespaces
kubectl describe certificate <cert-name> -n <namespace>

# Renew certificate
kubectl delete certificate <cert-name> -n <namespace>
kubectl apply -f certificate.yaml

# Check cert-manager logs
kubectl logs -n cert-manager deployment/cert-manager
```

### Security Scanning
```bash
# Scan container images
trivy image <image-name>

# Scan Kubernetes manifests
kubectl apply --dry-run=client -f manifest.yaml | trivy config -

# Check pod security standards
kubectl get pods --all-namespaces -o jsonpath='{range .items[*]}{.metadata.namespace}{"\t"}{.metadata.name}{"\t"}{.spec.securityContext}{"\n"}{end}'
```

### Access Management
```bash
# Check RBAC permissions
kubectl auth can-i <verb> <resource> --as=<user> -n <namespace>

# List role bindings
kubectl get rolebindings,clusterrolebindings --all-namespaces -o wide

# Check service account tokens
kubectl get serviceaccounts --all-namespaces
kubectl describe serviceaccount <sa-name> -n <namespace>
```

---

## 🚀 Deployment Operations

### Blue-Green Deployment
```bash
# Check current deployment
kubectl get deployments -l version=blue
kubectl get deployments -l version=green

# Switch traffic
kubectl patch service <service-name> -p '{"spec":{"selector":{"version":"green"}}}'

# Rollback if needed
kubectl patch service <service-name> -p '{"spec":{"selector":{"version":"blue"}}}'
```

### Canary Deployment
```bash
# Scale canary deployment
kubectl scale deployment <app-name>-canary --replicas=2

# Monitor canary metrics
kubectl logs -f deployment/<app-name>-canary

# Promote canary
kubectl scale deployment <app-name>-canary --replicas=10
kubectl scale deployment <app-name>-stable --replicas=0
```

---

## 📋 Maintenance Procedures

### Scheduled Maintenance

#### Cluster Upgrade
```bash
# 1. Check current version
kubectl version --short

# 2. Upgrade control plane
aws eks update-cluster-version --name platform-prod --version 1.29

# 3. Wait for upgrade completion
aws eks describe-cluster --name platform-prod --query 'cluster.status'

# 4. Upgrade node groups
aws eks update-nodegroup-version --cluster-name platform-prod --nodegroup-name main --kubernetes-version 1.29

# 5. Verify upgrade
kubectl get nodes
kubectl get pods --all-namespaces
```

#### Database Maintenance
```bash
# 1. Create snapshot
aws rds create-db-snapshot --db-instance-identifier platform-prod-db --db-snapshot-identifier pre-maintenance-$(date +%Y%m%d)

# 2. Apply maintenance
aws rds modify-db-instance --db-instance-identifier platform-prod-db --apply-immediately

# 3. Monitor maintenance
aws rds describe-events --source-identifier platform-prod-db --duration 60
```

### Backup Procedures

#### Kubernetes Backup
```bash
# Backup using Velero
velero backup create platform-backup-$(date +%Y%m%d) --include-namespaces="*"

# Check backup status
velero backup describe platform-backup-$(date +%Y%m%d)

# List backups
velero backup get
```

#### Database Backup
```bash
# Manual RDS snapshot
aws rds create-db-snapshot --db-instance-identifier platform-prod-db --db-snapshot-identifier manual-backup-$(date +%Y%m%d%H%M%S)

# Export data
kubectl run -it --rm pg-dump --image=postgres:15 --restart=Never -- pg_dump -h <db-host> -U <username> -d <database> > backup.sql
```

---

## 📞 Contact Information

### On-Call Rotation
- **Primary**: Platform Team Lead
- **Secondary**: Senior Platform Engineer
- **Escalation**: Engineering Manager

### Emergency Contacts
- **PagerDuty**: `+1-XXX-XXX-XXXX`
- **Slack**: `#platform-team`
- **Email**: `platform-team@company.com`

### Vendor Support
- **AWS Support**: Case routing via AWS Console
- **Kubernetes**: Community support via Slack
- **Crossplane**: GitHub issues and Slack

---

## 📚 Additional Resources

### Documentation Links
- [Architecture Overview](../architecture/overview.md)
- [Quick Start Guide](../tutorials/quick-start.md)
- [API Documentation](https://api-docs.platform.com)
- [Grafana Dashboards](https://grafana.platform.com)

### Tools and CLIs
- `kubectl` - Kubernetes CLI
- `argocd` - ArgoCD CLI
- `aws` - AWS CLI
- `helm` - Helm CLI
- `velero` - Backup CLI

### Training Resources
- [Crossplane Documentation](https://crossplane.io/docs)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io)
- [Kubernetes Documentation](https://kubernetes.io/docs)
