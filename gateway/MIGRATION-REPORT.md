# Envoy Gateway → KGateway Migration Report

**Date:** 2026-06-23  
**Version:** KGateway open-source v2.3.4  
**Domain:** invest-iq.online

---

## Legacy Ingress Inventory (pre-cleanup)

Verified before migration — **not serving traffic**:

| Namespace | Ingress | Host | ALB | Pods |
|-----------|---------|------|-----|------|
| ai-travel | nginx-proxy | api.invest-iq.online | k8s-aitravelapi-* | 0/0 |
| ai-travel | user-service | api.invest-iq.online | k8s-aitravel-userserv-* | 0/0 |
| ai-travel | travel-service | api.invest-iq.online | k8s-aitravel-travelse-* | 0/0 |
| ai-travel | ai-service | api.invest-iq.online | k8s-aitravel-aiservic-* | 0/0 |
| ai-travel | utility-service | api.invest-iq.online | k8s-aitravel-utilitys-* | 0/0 |

Production traffic runs in `prod` / `dev` namespaces via Gateway API HTTPRoutes.

---

## Files Removed

| File |
|------|
| `gateway/01-envoyproxy-nlb.yaml` |
| `gateway/01-gatewayclass.yaml` |
| `gateway/03-certificate.yaml` |
| `gateway/04-envoy-pdb.yaml` |
| `gateway/install-envoy-gateway.ps1` |
| `argocd-apps/applications/prod/envoy-gateway.yaml` |

---

## Files Added

| File | Purpose |
|------|---------|
| `argocd-apps/applications/infrastructure/kgateway-crds.yaml` | KGateway CRDs (wave -3) |
| `argocd-apps/applications/infrastructure/kgateway.yaml` | KGateway controller (wave -2) |
| `gateway/01-gateway-parameters-nlb.yaml` | NLB + ACM + 3 replicas |
| `gateway/03-gateway-pdb.yaml` | PodDisruptionBudget |
| `scripts/cleanup-legacy-ingress.ps1` | Safe legacy Ingress removal |
| `gateway/MIGRATION-REPORT.md` | This document |

---

## Files Modified

| File | Change |
|------|--------|
| `gateway/00-namespace.yaml` | `gateway-system` → `kgateway-system` |
| `gateway/02-gateway.yaml` | KGateway GatewayClass + GatewayParameters |
| `gateway/kustomization.yaml` | KGateway resource list |
| `gateway/routes/prod-routes.yaml` | Removed frontend route; KGateway parentRefs |
| `gateway/routes/dev-routes.yaml` | Removed frontend route; KGateway parentRefs |
| `gateway/README.md` | KGateway documentation |
| `argocd-apps/projects/planmyjourney.yaml` | OCI repos, kgateway-system |
| `argocd-apps/applications/prod/gateway-routes.yaml` | Destination namespace |
| `scripts/argocd-sync-all.ps1` | KGateway sync order |
| `scripts/update-route53-gateway.ps1` | KGateway NLB DNS |
| `scripts/cleanup-unused-aws-resources.ps1` | Updated keep patterns |

---

## CRDs Installed

Via `platform-kgateway-crds` Helm chart v2.3.4:

- `gateway.kgateway.dev/v1alpha1` — GatewayParameters, TrafficPolicy, etc.
- Standard Gateway API CRDs (already on EKS 1.30)

---

## ArgoCD Applications

| Application | Wave | Status |
|-------------|------|--------|
| `platform-kgateway-crds` | -3 | New |
| `platform-kgateway` | -2 | New |
| `prod-gateway-routes` | 1 | Updated |
| `prod-envoy-gateway` | — | **Removed** |

---

## Target Architecture

```
Route53 (api.invest-iq.online) → NLB (ACM :443) → KGateway → HTTPRoute → Services
Route53 (invest-iq.online)     → CloudFront → S3
ArgoCD NLB                     → Temporary (ClusterIP migration later)
```

---

## Validation Commands

```powershell
kubectl get pods -n kgateway-system
kubectl get gatewayclass kgateway
kubectl get gateway api-gateway -n kgateway-system
kubectl get httproute -A
kubectl get crd | Select-String envoyproxy    # should be empty
kubectl get pods -n envoy-gateway-system      # should be empty after prune

aws elbv2 describe-load-balancers --query "LoadBalancers[*].LoadBalancerName"

curl -I https://api.invest-iq.online/api/users/health
```

---

## Post-Migration Steps

1. Sync ArgoCD: `.\scripts\argocd-sync-all.ps1`
2. Wait for KGateway NLB: `kubectl get gateway api-gateway -n kgateway-system`
3. Update DNS: `.\scripts\update-route53-gateway.ps1`
4. Verify API health endpoints
5. Remove legacy ALBs: `.\scripts\cleanup-legacy-ingress.ps1`
6. Terraform: `terraform apply` with `enable_legacy_alb=false`

---

## Rollback Procedure

1. `git checkout pre-kgateway-migration` (tag created before migration)
2. Re-sync `prod-envoy-gateway` and gateway manifests
3. Run `update-route53-gateway.ps1` against Envoy NLB DNS
4. `helm uninstall kgateway kgateway-crds -n kgateway-system`

---

## Load Balancer Target State

| LB | Keep? |
|----|-------|
| KGateway NLB | Yes |
| ArgoCD NLB | Yes (temporary) |
| ai-travel-alb-prod | No — Terraform destroy |
| k8s-aitravel-* (5 ALBs) | No — delete Ingress |
