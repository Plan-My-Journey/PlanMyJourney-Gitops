# Plan My Journey — GitOps

Declarative Kubernetes deployments using **Flux CD** (AWS CodeConnections + EKS GitOps).

Organization: [Plan-My-Journey](https://github.com/orgs/Plan-My-Journey)

## Structure

```
helm-charts/          # Helm charts per microservice
kustomize/
  base/               # Namespace, RBAC, probes, HPA, PDB, NetworkPolicy
  overlays/dev/       # Dev environment patches
  overlays/prod/      # Production patches
kubernetes/           # Capstone evaluation manifest layout
flux/prod/            # Flux GitRepository + Kustomization
```

## Validation

```bash
kubectl apply -f kubernetes/ --dry-run=client
kustomize build kustomize/overlays/dev
kustomize build kustomize/overlays/prod
helm lint helm-charts/user-service --strict
```

## GitOps Flow

1. CI pushes images to ECR
2. Deploy workflow updates image tags in this repo
3. Flux reconciles `kustomize/overlays/prod` every 5 minutes
4. Kubernetes rolls out with HPA/PDB/NetworkPolicy

## Migration from ArgoCD

ArgoCD manifests in `argocd-apps/` are retained for reference only. Production GitOps uses AWS-managed Flux via CodeConnections.
