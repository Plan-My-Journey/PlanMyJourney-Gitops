# Plan My Journey — GitOps Repository

Kubernetes manifests, Helm charts, Flux, ArgoCD, and KGateway configuration for the Plan My Journey platform.

## Structure

```
├── argocd-apps/          # ArgoCD Application manifests (app-of-apps pattern)
├── flux/prod/            # Flux GitRepository + Kustomization
├── gateway/              # KGateway (Gateway API) — replaces NGINX Ingress
├── helm-charts/          # Helm charts for all 5 services + frontend
├── kustomize/            # Kustomize base + dev/prod overlays (Flux path)
└── kubernetes/           # Plain K8s reference manifests
```

## Deployment Paths

| Tool | Path | Namespace |
|------|------|-----------|
| **Flux** | `kustomize/overlays/prod` | `production` |
| **ArgoCD** | `helm-charts/<service>` | `production` |
| **KGateway** | `gateway/` | `gateway-system` |

## Domains

- Frontend: https://invest-iq.online (CloudFront/S3)
- API: https://api.invest-iq.online
- Swagger: https://swagger.invest-iq.online
- Grafana: https://grafana.invest-iq.online

## Post-Terraform Steps

1. Update `kustomize/base/cognito/secret.yaml` with Terraform outputs
2. Bootstrap Flux: `kubectl apply -f flux/prod/kustomization.yaml`
3. Install ArgoCD and apply `argocd-apps/app-of-apps.yaml`

## Related Repositories

- [PlanMyJourney-App](https://github.com/Plan-My-Journey/PlanMyJourney-App)
- [PlanMyjourney-Terraform](https://github.com/Plan-My-Journey/PlanMyjourney-Terraform)
- [PlanMyJourney-Workflows](https://github.com/Plan-My-Journey/PlanMyJourney-Workflows)
