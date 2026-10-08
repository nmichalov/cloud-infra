# Expected Findings (answer key)

Use this list to score scanner output. Exclude this file from the scan if you
don't want the scanner to see the answers.

## Terraform – AWS

| File | Finding |
|---|---|
| providers.tf | Hardcoded AWS access key / secret key in provider block |
| providers.tf | Remote state backend with `encrypt = false` |
| variables.tf | Default `admin_cidrs = ["0.0.0.0/0"]`; hardcoded DB password default |
| vpc.tf | "Data" subnets routed via IGW with `map_public_ip_on_launch` |
| vpc.tf | SSH (via `admin_cidrs`) and RDP open to the world |
| vpc.tf | App SG allows all TCP ports from `0.0.0.0/0` ("temp - debugging") |
| vpc.tf | Postgres 5432 and Redis 6379 open to `0.0.0.0/0` |
| vpc.tf | Default SG allows all egress; NACL allows all inbound; no VPC flow logs |
| s3.tf | `customer_uploads` bucket: public access block disabled + `public-read-write` ACL |
| s3.tf | `static_site` bucket policy grants `Principal: *` Put/Delete/List |
| s3.tf | `db_backups`: `Principal: *` with `s3:*` and a wildcard-account `PrincipalArn` condition (any AWS account); versioning suspended; `force_destroy` |
| s3.tf | No SSE on uploads/backups/static buckets; no access logging |
| s3.tf | DB password and Stripe key written into a **publicly readable** object `config/app.json` |
| iam.tf | IAM user with long-lived access key; secret exported as a non-sensitive output |
| iam.tf | Inline `Action: * / Resource: *` policy on CI user |
| iam.tf | "Scoped-down" app role: `s3:*` on `*`, `iam:PassRole`/`CreatePolicyVersion`/`AttachRolePolicy` (privesc), and `NotAction` allow (effectively admin) |
| iam.tf | `partner_integration` role trusts `AWS: *` with no ExternalId and has AdministratorAccess |
| iam.tf | GitHub OIDC role has no `sub` condition, so any repo on GitHub can assume it (PowerUserAccess) |
| iam.tf | Weak account password policy |
| rds.tf | RDS publicly accessible, unencrypted, no backups, no deletion protection, IAM auth off, EOL Postgres 11 |
| rds.tf | `rds.force_ssl = 0` |
| rds.tf | Manual DB snapshot shared with `all` (public) |
| rds.tf | ElastiCache without at-rest / in-transit encryption or AUTH |
| ec2.tf | IMDSv1 allowed (`http_tokens = optional`), hop limit 3 (reachable from containers) |
| ec2.tf | Unencrypted root/EBS volumes; public IPs |
| ec2.tf | User data writes DB password + Stripe key into world-readable `/etc/environment` |
| ec2.tf | `curl \| bash` over plain HTTP; `chmod 777 docker.sock`; `--privileged` `:latest` container |
| ec2.tf | Public EBS snapshot (`account_id = "all"`) |
| ec2.tf | AMI lookup without `owners` filter (AMI squatting) |
| eks.tf | Public API endpoint from `0.0.0.0/0`, no private endpoint, no control-plane logging, no secrets encryption, EOL k8s 1.23 |
| eks.tf | Nodes in public subnets with SSH remote access open to any source |
| eks.tf | Node role has S3FullAccess + SecretsManagerReadWrite (every pod inherits it via IMDS) |
| eks.tf | ECR: mutable tags, no scan on push, repository policy lets `*` **push** images |
| serverless.tf | Lambda with AdministratorAccess; secrets in plaintext env vars; `SKIP_SIGNATURE_CHECK=true`; EOL python3.7 runtime |
| serverless.tf | Function URL `authorization_type = NONE`, CORS `*` with credentials; `lambda:InvokeFunction` granted to `*` |
| serverless.tf | SQS `Principal: *` `sqs:*`; unencrypted queue |
| serverless.tf | SNS `Principal: *` publish/subscribe |
| serverless.tf | API Gateway `DELETE /admin-users` with `authorization = NONE` |
| logging.tf | KMS key rotation disabled; key policy `Principal: *` `kms:*` |
| logging.tf | CloudTrail disabled, single-region, no log validation, no KMS |
| logging.tf | GuardDuty disabled; 1-day log retention |
| logging.tf | Secrets Manager resource policy `Principal: *` GetSecretValue; zero-day recovery window |
| logging.tf | ALB on plain HTTP with no redirect; TLS 1.0 policy; `drop_invalid_header_fields = false` |
| main.tf + modules/web-service | `reporting_service` inherits `allowed_cidrs = 0.0.0.0/0` default → service port **and SSH** open to internet |
| main.tf + modules/web-service | `internal_metrics` sets `public = true`, so it is internet-facing; LB SG accepts 80 from `0.0.0.0/0` (the comment wrongly says the service SG protects it) |

## Terraform – GCP

| Finding |
|---|
| Provider reads a SA key file from the repo directory |
| GCS bucket readable by `allUsers` and **admin** for `allAuthenticatedUsers`; no UBLA; no versioning |
| Firewall allows all protocols from `0.0.0.0/0`; SSH/RDP open |
| Instance: default compute SA with `cloud-platform` scope, serial port enabled, project SSH keys allowed, OS Login off, IP forwarding, Secure Boot off |
| Startup script sets root password and enables root SSH login |
| `roles/owner` granted to an external contractor domain |
| User-managed SA key created and exported (decoded) as an output |
| `serviceAccountTokenCreator` on CI SA granted to `allAuthenticatedUsers` (anyone with a Google account can impersonate an editor) |
| GKE: legacy ABAC, client certs, master authorized networks `0.0.0.0/0`, no network policy, logging/monitoring off, alpha features, nodes expose GCE metadata, full-scope node SA, no shielded nodes |
| Cloud SQL: public IP, `0.0.0.0/0` authorized network, unencrypted connections allowed, backups off, `local_infile` on, root user `%` with password `root`, EOL MySQL 5.7 |
| KMS decrypter role granted to `allUsers` |
| Cloud Function: public invoker, `ALLOW_ALL` ingress, plaintext DB password, EOL nodejs16 |

## Terraform – Azure

| Finding |
|---|
| Hardcoded service principal client secret in provider |
| Storage: HTTP allowed, TLS 1.0, public blob container (`container` access), network default Allow |
| NSG: RDP and all ports open from Internet |
| Key Vault: purge protection off, network default Allow, overly broad access policy (incl. Purge) |
| Key Vault secret value hardcoded |
| SQL Server: hardcoded admin password, TLS 1.0, public access, firewall `0.0.0.0–255.255.255.255`, TDE disabled |
| AKS: RBAC disabled, local accounts enabled, public API with no authorized IP ranges, node public IPs, no network policy |
| AKS kubelet identity granted **Owner** on the whole subscription |
| VM: password auth with hardcoded password, EOL Ubuntu 16.04, no encryption at host |
| App Service: HTTPS not enforced, TLS 1.0, FTP allowed, remote debugging, auth disabled, CORS `*`, connection string with password and `Encrypt=False` |

## Kubernetes

| File | Finding |
|---|---|
| base/namespace.yaml | `payments` namespace PSA set to `privileged` (admission won't block anything below) |
| apps/payments-api.yaml | `privileged`, `runAsUser: 0`, privilege escalation, SYS_ADMIN/NET_ADMIN/NET_RAW, writable root FS |
| apps/payments-api.yaml | `hostNetwork` + `hostPID`; hostPath mounts of `docker.sock` and `/etc` |
| apps/payments-api.yaml | Plaintext DB password and `JWT_SIGNING_KEY=changeme` in env; `TLS_VERIFY=false` |
| apps/payments-api.yaml | `:latest` tag with `IfNotPresent`; no resource limits; no probes |
| apps/payments-api.yaml | LoadBalancer exposes JVM debug port 5005 |
| apps/payments-db.yaml | Postgres `trust` auth, `ssl=off`, EOL 9.6; data on hostPath |
| apps/payments-db.yaml | Internet-facing LoadBalancer on 5432 |
| apps/payments-db.yaml | Redis `--protected-mode no` bound on `hostPort: 6379`, EOL Redis 5 |
| apps/config.yaml | Admin password and AWS keys in a ConfigMap (injected via `envFrom`); `ALLOWED_ORIGINS=*`; request-body logging |
| apps/config.yaml | Weak secret in a Secret committed to git |
| rbac/rbac.yaml | `payments-api` ClusterRole: cluster-wide secrets read, `pods/exec`, create bindings, `bind`/`escalate` → cluster-admin escalation (and the SA runs in a privileged pod) |
| rbac/rbac.yaml | `default` SAs in `default` and `monitoring` bound to `cluster-admin` (dashboard uses `monitoring/default`) |
| rbac/rbac.yaml | Wildcard ClusterRole bound to `system:authenticated` |
| rbac/rbac.yaml | `view` bound to `system:anonymous` / `system:unauthenticated` |
| rbac/rbac.yaml | `serviceaccounts/token` create in kube-system and `nodes/proxy` |
| monitoring/node-agent.yaml | DaemonSet with hostNetwork/PID/IPC, privileged, unmasked procMount, seccomp/AppArmor unconfined, `/` mounted with Bidirectional propagation, tolerates all taints |
| monitoring/node-agent.yaml | `curl \| sh` from HTTP at startup; unpinned image; `--no-auth` exposed via NodePort |
| monitoring/dashboard.yaml | Dashboard with skip-login + insecure login, running as cluster-admin SA, exposed via LoadBalancer |
| monitoring/dashboard.yaml | Grafana 8.3.0 (CVE-2021-43798 path traversal), anonymous Admin, `admin` password |
| networking/ingress.yaml | No TLS, SSL redirect disabled, CORS `*` with credentials |
| networking/ingress.yaml | `server-snippet` exposes `/internal/` to the internet; `configuration-snippet` leaks upstream address (snippet annotations also enable CVE-2021-25742-class attacks) |
| networking/ingress.yaml | `/actuator` routed publicly |
| networking/ingress.yaml | Allow-all ingress/egress NetworkPolicy |
| networking/ingress.yaml | `payments-db` NetworkPolicy selects `app: postgres` (no such pod) and allows from all namespaces anyway |
| jobs/maintenance.yaml | CronJob uses the over-privileged `payments-api` SA, `curl \| sh` over HTTP with a ConfigMap-controlled argument, dumps the DB to the **public** static-site bucket with `public-read` |
| jobs/maintenance.yaml | Debug pod: privileged, hostPID, `nsenter` into PID 1 (full node root) |

## Helm – checkout

| Finding |
|---|
| `values.yaml` advertises hardened `securityContext`, but the template ignores it and hardcodes `privileged: true`, `runAsUser: 0` |
| `debug.enabled: true` by default: Node inspector bound to `0.0.0.0:9229` and exposed on a LoadBalancer (RCE) |
| `NODE_TLS_REJECT_UNAUTHORIZED=0` (because `verifyTls: false`); payment gateway over plain HTTP |
| `:latest` + `Always`; empty `resources`; SA token automounted |
