# Plan My Journey — GitOps Repository

Kubernetes manifests and Helm charts for **ArgoCD** GitOps on EKS.

Organization: [Plan-My-Journey](https://github.com/orgs/Plan-My-Journey)

## Structure

```
argocd-apps/          # ArgoCD Application manifests (app-of-apps pattern)
argocd/               # ArgoCD install script
helm-charts/          # Helm charts for all microservices + frontend
kustomize/            # Kustomize base + dev/prod overlays (reference / capstone layout)
kubernetes/           # Plain K8s manifests for evaluation dry-run
gateway/              # KGateway (Gateway API) configuration
```

## GitOps Flow (ArgoCD)

```
CI builds image → pushes to ECR
       ↓
Deploy workflow updates helm-charts/*/values.yaml image tags
       ↓
git push to planmyjourney-gitops
       ↓
ArgoCD detects diff → auto-sync → EKS rollout
```

## Bootstrap ArgoCD

```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl apply -f argocd-apps/projects/ai-travel.yaml
kubectl apply -f argocd-apps/app-of-apps.yaml
```

Or use `argocd/install.sh`.

## Validation

```bash
kubectl apply -f kubernetes/ --dry-run=client
helm lint helm-charts/user-service --strict
kustomize build kustomize/overlays/prod
```

## Related Repositories

- [planmyjourney-app](https://github.com/Plan-My-Journey/planmyjourney-app)
- [planmyjourney-terraform](https://github.com/Plan-My-Journey/planmyjourney-terraform)
- [planmyjourney-workflows](https://github.com/Plan-My-Journey/planmyjourney-workflows)
