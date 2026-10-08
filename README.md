# cloud-infra

> ⚠️ **Intentionally vulnerable.** This repository is a demo corpus for showcasing
> AI-powered SAST against infrastructure-as-code. Every file contains deliberate
> misconfigurations. **Do not `terraform apply`, `kubectl apply`, or `helm install`
> anything in this repo.** All credentials are fake placeholders.

## Layout

```
terraform/
  aws/            VPC, S3, IAM, RDS/ElastiCache, EC2, EKS/ECR, Lambda/SQS/SNS/API GW, KMS/CloudTrail/ALB
  gcp/            GCS, Compute, IAM, GKE, Cloud SQL, KMS, Cloud Functions
  azure/          Storage, NSG, Key Vault, SQL, AKS, VM, App Service
  modules/
    web-service/  Reusable ALB + SG module (insecure defaults consumed from aws/main.tf)
kubernetes/
  base/           Namespaces / Pod Security Admission labels
  apps/           payments-api, Postgres, Redis, ConfigMap/Secret
  rbac/           ClusterRoles and bindings
  monitoring/     Node agent DaemonSet, Kubernetes Dashboard, Grafana
  networking/     Ingress and NetworkPolicies
  jobs/           CronJob and a debug pod
helm/
  checkout/       Chart whose values.yaml looks hardened but the template ignores it
```

## What makes this a good AI SAST demo

Besides the obvious pattern-matchable issues (`0.0.0.0/0`, `privileged: true`,
`Action: "*"`), several findings require reasoning across lines or files, which
rule-based scanners usually miss:

- **Module defaults.** `terraform/aws/main.tf` calls `modules/web-service` without
  `allowed_cidrs`, so the module's `0.0.0.0/0` default opens SSH on port 22 to the internet.
- **Misleading comments.** The "scoped-down" IAM policy in `iam.tf` contains
  `iam:PassRole`, `iam:AttachRolePolicy` and a `NotAction` allow, which add up to full
  privilege escalation.
- **Unconstrained OIDC trust.** The GitHub Actions role checks only `aud` and not `sub`,
  so any GitHub repository can assume it.
- **Selectors that don't match.** The `payments-db` NetworkPolicy selects `app: postgres`,
  but the pod is labeled `app: payments-db`, so the policy protects nothing.
- **Helm values vs. template.** `values.yaml` declares a hardened `securityContext`, but
  `templates/deployment.yaml` hardcodes `privileged: true` / `runAsUser: 0`.
- **Data-flow exposure.** DB credentials flow from `variables.tf` into a public S3 object
  (`s3.tf`), EC2 user data (`ec2.tf`) and Lambda env vars (`serverless.tf`).

See [EXPECTED_FINDINGS.md](EXPECTED_FINDINGS.md) for the full answer key.
