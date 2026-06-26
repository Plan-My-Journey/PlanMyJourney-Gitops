# Plan My Journey — GitOps Repository

Kubernetes manifests and Helm charts for **ArgoCD** GitOps on EKS.

Organization: [Plan-My-Journey](https://github.com/orgs/Plan-My-Journey)

## Structure

```
argocd/               # ArgoCD install (Helm values + bootstrap scripts)
argocd-apps/          # ArgoCD Application manifests (app-of-apps pattern)
  ├── app-of-apps.yaml
  ├── projects/       # AppProject definition
  └── applications/
      ├── infrastructure/   # karpenter, keda, kgateway, shared gateway
      ├── dev/              # dev service apps + gateway routes
      └── prod/             # prod service apps + gateway routes
helm-charts/          # Helm charts for all microservices + frontend (deploy unit)
gateway/              # KGateway (Gateway API) config — plain manifests
platform/             # Karpenter EC2NodeClass / NodePool
scripts/              # Operational helper scripts
```

Each service is deployed from its Helm chart under `helm-charts/`. There is a
single source of truth — no Kustomize overlays or duplicate plain-manifest copies.

## GitOps flow

```
CI builds image → pushes to ECR
       ↓
Deploy updates helm-charts/<svc>/values-<env>.yaml image tag → git push
       ↓
ArgoCD detects diff → auto-sync (prune + selfHeal) → EKS rollout
```

## Bootstrap ArgoCD

```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl apply -f argocd-apps/projects/planmyjourney.yaml
kubectl apply -f argocd-apps/app-of-apps.yaml
```

Or use `argocd/install.sh` (`argocd/install.ps1` on Windows).

## Validation

```bash
helm lint helm-charts/user-service --strict
kubectl apply --dry-run=client -f gateway/base/
```

## Related repositories

- [planmyjourney-app](https://github.com/Plan-My-Journey/planmyjourney-app)
- [planmyjourney-terraform](https://github.com/Plan-My-Journey/planmyjourney-terraform)
