# Kubernetes Manifests for Tasky Application

This directory contains Kubernetes manifests for deploying the Tasky todo application on Kubernetes/EKS.

## Files

- **namespace.yaml**: Creates the `tasky-app` namespace
- **deployment.yaml**: Defines the application deployment with 3 replicas
- **service.yaml**: Creates a ClusterIP service for internal access
- **ingress.yaml**: Configures ALB ingress for external access
- **rbac.yaml**: Sets up service account and RBAC permissions

## Deployment

Apply manifests in order:

```bash
kubectl apply -f namespace.yaml
kubectl apply -f rbac.yaml
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml
kubectl apply -f ingress.yaml
```

Or apply all at once:

```bash
kubectl apply -f k8s/ --namespace=tasky-app
```

## Verify Deployment

```bash
# Check pods
kubectl get pods -n tasky-app

# Check services
kubectl get svc -n tasky-app

# Check ingress
kubectl get ingress -n tasky-app

# View logs
kubectl logs -f deployment/tasky-deployment -n tasky-app

# Verify wizexercise.txt file
kubectl exec -it deployment/tasky-deployment -n tasky-app -- cat /app/wizexercise.txt
```

## Intentional Security Misconfigurations (Per Exercise Requirements)

The following security issues are **intentionally** configured for the Wiz Technical Exercise:

1. **Privileged Container**: `securityContext.privileged: true`
2. **Cluster Admin Role**: Container has cluster-admin RBAC permissions
3. **Root User**: Container runs as root (`runAsNonRoot: false`)
4. **Privilege Escalation**: `allowPrivilegeEscalation: true`

These should be detected by security scanning tools during the CI/CD pipeline.
