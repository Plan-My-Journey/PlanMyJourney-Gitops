# KGateway (Gateway API)

Open-source [KGateway v2.3.4](https://kgateway.dev) replaces the former Envoy Gateway controller.

## Architecture

```
Route53 (api.invest-iq.online)
    ↓
AWS NLB (ACM TLS :443)
    ↓ HTTP :80
KGateway proxy (kgateway-system)
    ↓ HTTPRoute
prod/dev microservices
```

Frontend traffic uses **CloudFront → S3** only (no HTTPRoute for apex/www).

## Files

| File | Purpose |
|------|---------|
| `00-namespace.yaml` | `kgateway-system` namespace |
| `01-gateway-parameters-nlb.yaml` | NLB + ACM annotations, 3 replicas |
| `02-gateway.yaml` | `Gateway` (`api-gateway`) |
| `03-gateway-pdb.yaml` | HA disruption budget |
| `routes/prod-routes.yaml` | Production API HTTPRoutes |
| `routes/dev-routes.yaml` | Development API HTTPRoutes |

## ArgoCD

| Application | Wave | Purpose |
|-------------|------|---------|
| `platform-kgateway-crds` | -3 | KGateway CRDs |
| `platform-kgateway` | -2 | KGateway controller |
| `prod-gateway-routes` | 1 | Gateway + HTTPRoutes |

## Operations

```powershell
# After sync, point API DNS to the new NLB
.\scripts\update-route53-gateway.ps1

# Verify
kubectl get gateway api-gateway -n kgateway-system
kubectl get httproute -A
kubectl get pods -n kgateway-system
```

## ACM rotation

Update `service.beta.kubernetes.io/aws-load-balancer-ssl-cert` in `01-gateway-parameters-nlb.yaml`, then sync `prod-gateway-routes`.

## Legacy cleanup

After KGateway is healthy and Route53 is updated:

```powershell
.\scripts\cleanup-legacy-ingress.ps1
```

See `MIGRATION-REPORT.md` for full migration details and rollback.
