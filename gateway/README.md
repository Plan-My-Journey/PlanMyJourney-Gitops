# Gateway TLS with ACM + Route53

This gateway uses **AWS ACM** for TLS and **Route53** for DNS. cert-manager is not required.

## How TLS works

1. ACM certificate (already in Terraform): `arn:aws:acm:us-east-1:235270183260:certificate/91b9e8c2-6c81-4e7c-819c-34fb260aa246`
2. Envoy Gateway NLB annotations in `01-envoyproxy-nlb.yaml` terminate HTTPS on port 443.
3. Traffic is forwarded to Envoy on HTTP port 80 inside the cluster.
4. HTTPRoutes attach to the Gateway `http` listener (`sectionName: http`).

## Route53 setup

After the Gateway NLB hostname is assigned:

```powershell
.\scripts\update-route53-gateway.ps1
```

This creates/updates alias records for:

- `invest-iq.online`
- `www.invest-iq.online`
- `api.invest-iq.online`
- `dev.invest-iq.online`
- `dev-api.invest-iq.online`

## Verify

```powershell
kubectl get gateway api-gateway -n gateway-system
kubectl get httproute -A
curl -I https://api.invest-iq.online/health
```

## Notes

- Do not apply `03-certificate.yaml` (cert-manager). It is intentionally excluded from `kustomization.yaml`.
- If you rotate the ACM certificate, update the annotation in `01-envoyproxy-nlb.yaml` and re-sync `prod-gateway-routes`.
