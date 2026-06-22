# Envoy Gateway + NLB (KGateway Provider)

Traffic enters through an **AWS Network Load Balancer** provisioned by **Envoy Gateway** (`gateway.envoyproxy.io` controller). Per-service **Ingress** resources are removed; routing uses **Gateway API HTTPRoute** objects.

## Architecture

```
Internet → AWS NLB → Envoy Gateway → HTTPRoute → ClusterIP Services
```

| Component | Location |
|-----------|----------|
| Envoy Gateway controller | `envoy-gateway-system` |
| Gateway + EnvoyProxy (NLB config) | `gateway-system` |
| HTTPRoutes (prod) | `prod` namespace |
| HTTPRoutes (dev) | `dev` namespace |

## ArgoCD apps (sync order)

1. **prod-envoy-gateway** (wave 0) — installs Envoy Gateway Helm chart, creates GatewayClass `eg`
2. **prod-gateway-routes** (wave 1) — NLB Gateway + HTTPRoutes for dev/prod

## Manual install (alternative)

```powershell
.\gateway\install-envoy-gateway.ps1
kubectl apply -k gateway/
```

## Get NLB hostname

```powershell
kubectl get gateway api-gateway -n gateway-system -o jsonpath='{.status.addresses[0].value}'
```

Point DNS `api.invest-iq.online`, `invest-iq.online`, `dev-api.invest-iq.online`, `dev.invest-iq.online` to this NLB.

## TLS

TLS termination at the Gateway uses cert-manager (`gateway/03-certificate.yaml`). Install cert-manager before syncing routes if HTTPS is required.
