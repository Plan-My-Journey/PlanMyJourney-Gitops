# KGateway (Gateway API)

Open-source [KGateway v2.3.4](https://kgateway.dev) provides the Gateway API
ingress for Plan My Journey.

## Architecture

```
Route53 (api.invest-iq.online / dev-api.invest-iq.online)
    ↓
AWS NLB (ACM TLS :443)
    ↓ HTTP :80
KGateway proxy (kgateway-system)
    ↓ HTTPRoute
prod / dev microservices
```

Frontend traffic uses **CloudFront → S3** only (no HTTPRoute for apex/www).

## Layout

```
gateway/
├── base/                     # shared gateway infra (kgateway-system)
│   ├── namespace.yaml
│   ├── gatewayparameters.yaml   # NLB + ACM annotations, 3 replicas
│   ├── gateway.yaml             # Gateway "api-gateway"
│   └── pdb.yaml                 # HA disruption budget
└── routes/
    ├── dev/routes.yaml       # dev HTTPRoutes  → namespace dev
    └── prod/routes.yaml      # prod HTTPRoutes → namespace prod
```

These are plain Kubernetes manifests — no Kustomize. ArgoCD applies each
directory directly.

## ArgoCD applications

| Application            | Wave | Path                  | Namespace        |
|------------------------|------|-----------------------|------------------|
| `platform-kgateway-crds` | -3 | (OCI chart)           | kgateway-system  |
| `platform-kgateway`      | -2 | (OCI chart)           | kgateway-system  |
| `platform-gateway`       | -1 | `gateway/base`        | kgateway-system  |
| `dev-gateway-routes`     |  1 | `gateway/routes/dev`  | dev              |
| `prod-gateway-routes`    |  1 | `gateway/routes/prod` | prod             |

## Operations

```powershell
# After sync, point API DNS to the NLB
.\scripts\update-route53-gateway.ps1

# Verify
kubectl get gateway api-gateway -n kgateway-system
kubectl get httproute -A
kubectl get pods -n kgateway-system
```

## ACM certificate rotation

Update `service.beta.kubernetes.io/aws-load-balancer-ssl-cert` in
`base/gatewayparameters.yaml`, then sync `platform-gateway`.
