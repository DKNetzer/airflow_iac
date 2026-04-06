# ✈️ Airflow on GKE Autopilot — Infrastructure as Code

> **Private-First · Zero-Waste · Multi-Customer**
> Deploy production-grade Apache Airflow on Google Kubernetes Engine Autopilot in ~25 minutes.

---

## 📋 Table of Contents

- [What This Repo Does](#what-this-repo-does)
- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Repository Structure](#repository-structure)
- [Configuration Reference](#configuration-reference)
- [Deployment Guide](#deployment-guide)
- [Daily Operations](#daily-operations)
- [Troubleshooting](#troubleshooting)
- [Cost Reference](#cost-reference)
- [Security Model](#security-model)
- [Multi-Customer Deployments](#multi-customer-deployments)

---

## What This Repo Does

This repository provisions a complete, production-ready Airflow environment on GCP using:

- **Terraform** — provisions all GCP infrastructure (VPC, GKE, Cloud SQL, IAM, GCS)
- **Helm** — deploys the Airflow application into the cluster
- **`deploy.sh`** — one command that runs all of the above in the correct order

It is designed to be **repeatable for any customer** by changing a single configuration file.

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    GCP Project                              │
│                                                             │
│  ┌─── Private VPC (10.10.0.0/20) ─────────────────────┐   │
│  │                                                      │   │
│  │  ┌─── GKE Autopilot ──────────────────────────┐    │   │
│  │  │                                             │    │   │
│  │  │  [Scheduler + git-sync + sql-proxy]        │    │   │
│  │  │  [Webserver  + sql-proxy]                  │    │   │
│  │  │  [Triggerer  + sql-proxy]                  │    │   │
│  │  │  [Worker Pod] ← created per task, deleted  │    │   │
│  │  │                   after completion          │    │   │
│  │  └─────────────────────────────────────────────┘    │   │
│  │                    │ Cloud SQL Auth Proxy             │   │
│  │  ┌─── Cloud SQL ───┘ (Private IP only) ──────┐      │   │
│  │  │  PostgreSQL 15 — Airflow metadata DB       │      │   │
│  │  └────────────────────────────────────────────┘      │   │
│  │                                                      │   │
│  │  ┌─── Cloud NAT ──────────────────────────────┐     │   │
│  │  │  Outbound internet for private pods        │     │   │
│  │  └────────────────────────────────────────────┘     │   │
│  └──────────────────────────────────────────────────────┘   │
│                                                             │
│  ┌─── GCS Bucket ─────────────────────────────────────┐    │
│  │  Task logs — Coldline at 30d, deleted at 90d        │    │
│  └─────────────────────────────────────────────────────┘    │
│                                                             │
└─────────────────────────────────────────────────────────────┘
          ↑
    Corporate VPN only
    (K8s API is private)
```

| Component | Technology | Why |
|---|---|---|
| Compute | GKE Autopilot | Pay per pod, not per idle server |
| Database | Cloud SQL PostgreSQL 15 | Managed, private IP, IAM auth |
| Task Executor | KubernetesExecutor | Zero idle worker cost |
| DAG Delivery | Git-Sync sidecar | No Docker rebuilds for DAG changes |
| Logging | GCS Remote Logging | Logs survive pod deletion |
| Auth | Workload Identity | No static keys or passwords |
| Networking | Private VPC + Cloud NAT | No public IPs on any node |

---

## Prerequisites

### Tools

```bash
brew install --cask google-cloud-sdk
brew install hashicorp/tap/terraform helm kubectl
```

Minimum versions: `gcloud 450+` · `terraform 1.7+` · `helm 3.12+`

### GCP Access

You need one of the following on your target GCP project:

- `roles/owner` — easiest for initial setup
- Or the specific roles: `container.admin`, `cloudsql.admin`, `compute.networkAdmin`, `iam.serviceAccountAdmin`, `iam.workloadIdentityPoolAdmin`, `secretmanager.admin`, `storage.admin`

### Authentication

```bash
gcloud auth application-default login
gcloud config set project YOUR_PROJECT_ID
```

---

## Quick Start

```bash
# Clone this repo
git clone git@github.com:YOUR_ORG/airflow_iac.git
cd airflow_iac

# Make the deploy script executable
chmod +x deploy.sh

# Deploy (takes ~25 minutes)
./deploy.sh \
  <customer>      \   # e.g. acme-corp
  <project_id>    \   # e.g. my-gcp-project
  <environment>   \   # dev or prod
  <vpn_cidr>      \   # e.g. 203.0.113.10/32  (run: curl ifconfig.me)
  <db_password>   \   # e.g. MySecurePass2026
  <dag_repo_url>      # e.g. git@github.com:acme/airflow-dags.git
```

**Example:**
```bash
./deploy.sh acme-corp my-gcp-project dev 203.0.113.10/32 AcmePass2026 git@github.com:acme/airflow-dags.git
```

The script will pause once to ask you to add a GitHub Deploy Key. After that it runs fully automated.

**Access the UI when done:**
```bash
kubectl port-forward svc/airflow-webserver 8080:8080 -n airflow
# Open: http://localhost:8080
# Login: admin / Admin{YEAR}!  (printed at end of deploy.sh)
```

---

## Repository Structure

```
airflow_iac/
├── deploy.sh                        # One-command deployment — start here
├── .gitignore                       # Protects secrets from git
├── helm/
│   └── values.yaml                  # Airflow Helm config (generated by deploy.sh)
└── terraform/
    ├── main.tf                      # Root: providers, API enablement, module calls
    ├── variables.tf                 # All input variables
    ├── outputs.tf                   # Cluster name, DB name, SA email
    ├── storage.tf                   # GCS logging bucket
    ├── helm.tf                      # Optional: Helm release via Terraform
    ├── terraform.tfvars             # ⚠️ YOUR VALUES — gitignored, never commit
    └── modules/
        ├── networking/              # VPC, subnets, Cloud NAT, firewall, SQL peering
        ├── gke/                     # GKE Autopilot private cluster
        ├── db/                      # Cloud SQL PostgreSQL 15
        └── iam/                     # GCP service account + IAM bindings
```

> **DAG files do NOT live here.** They live in a separate repository (e.g. `airflow-dags`). Git-Sync pulls from that repo into the cluster every 60 seconds.

---

## Configuration Reference

### terraform.tfvars

Create this file at `terraform/terraform.tfvars` — it is gitignored and must never be committed:

```hcl
project_id          = "my-gcp-project"
region              = "us-central1"
customer            = "acme-corp"          # Short slug, used in all resource names
environment         = "dev"                # dev or prod
authorized_vpn_cidr = "203.0.113.10/32"   # Run: curl ifconfig.me
enable_spot_workers = true
dag_repo_url        = "git@github.com:your-org/airflow-dags.git"
cloud_sql_tier      = "db-g1-small"       # Use db-custom-2-4096 for production
```

### Network CIDR Ranges

| Segment | CIDR | Purpose |
|---|---|---|
| Primary Subnet | `10.10.0.0/20` | GKE node IPs |
| GKE Pods | `10.20.0.0/16` | Pod IPs (65,534 max) |
| GKE Services | `10.30.0.0/20` | ClusterIP services |
| SQL Peering | `10.13.0.0/28` | Cloud SQL Private Service Access |
| GKE Master | `172.16.0.0/28` | Private K8s API server |

### Key Resource Names

All resources follow the pattern `{customer}-{resource}-{environment}`:

| Resource | Name Pattern | Example |
|---|---|---|
| GKE Cluster | `{customer}-gke` | `acme-corp-gke` |
| Cloud SQL | `{customer}-airflow-pg-{env}` | `acme-corp-airflow-pg-dev` |
| GCS Bucket | `{customer}-airflow-logs-{env}` | `acme-corp-airflow-logs-dev` |
| GCP SA | `{customer}-airflow-worker@...` | `acme-corp-airflow-worker@project.iam.gserviceaccount.com` |
| VPC | `{customer}-airflow-vpc` | `acme-corp-airflow-vpc` |
| State Bucket | `tf-state-{customer}-airflow` | `tf-state-acme-corp-airflow` |

---

## Deployment Guide

### First-Time Deployment

```bash
# 1. Create Terraform state bucket (one-time per customer)
gcloud storage buckets create gs://tf-state-{customer}-airflow \
  --location=us-central1 --project=YOUR_PROJECT_ID

# 2. Initialize Terraform
cd terraform && terraform init

# 3. Apply infrastructure in order (avoids race conditions)
terraform apply -target=module.networking -auto-approve  # ~2 min
terraform apply -target=module.db         -auto-approve  # ~10 min
terraform apply -target=module.gke        -auto-approve  # ~8 min
terraform apply -target=module.iam        -auto-approve  # ~1 min
terraform apply -target=google_storage_bucket.airflow_logs -auto-approve

# 4. Connect kubectl
gcloud container clusters get-credentials {customer}-gke \
  --region us-central1 --project YOUR_PROJECT_ID

# 5. Create Cloud SQL user
gcloud sql users create airflow \
  --instance={customer}-airflow-pg-dev \
  --password=YOUR_PASSWORD

# 6. Add Workload Identity bindings for all Airflow service accounts
SA_EMAIL="{customer}-airflow-worker@{project}.iam.gserviceaccount.com"
for KSA in airflow-worker airflow-scheduler airflow-webserver \
           airflow-triggerer airflow-migrate-database-job airflow-create-user-job; do
  gcloud iam service-accounts add-iam-policy-binding "$SA_EMAIL" \
    --role="roles/iam.workloadIdentityUser" \
    --member="serviceAccount:{project}.svc.id.goog[airflow/${KSA}]" \
    --condition=None
done

# 7. Create Kubernetes namespace and secrets
kubectl create namespace airflow
ssh-keygen -t ed25519 -f ~/.ssh/{customer}_airflow_github_key -N ""
# Add the .pub key to GitHub as a Deploy Key, then:
kubectl create secret generic airflow-ssh-git \
  --from-file=gitSshKey=$HOME/.ssh/{customer}_airflow_github_key -n airflow
kubectl create secret generic airflow-webserver-secret-key \
  --from-literal=webserver-secret-key=$(python3 -c "import secrets; print(secrets.token_hex(16))") \
  -n airflow

# 8. Deploy Airflow
cd .. && helm repo add apache-airflow https://airflow.apache.org
helm upgrade --install airflow apache-airflow/airflow \
  --namespace airflow --values helm/values.yaml \
  --version 1.14.0 --timeout 15m

# 9. Create admin user
kubectl exec -n airflow \
  $(kubectl get pod -n airflow -l component=scheduler -o jsonpath='{.items[0].metadata.name}') \
  -c scheduler -- \
  airflow users create --username admin --password Admin2026 \
  --firstname Admin --lastname User --role Admin --email admin@company.com
```

---

## Daily Operations

### Start the UI

```bash
# Make sure you are on VPN first
kubectl port-forward svc/airflow-webserver 8080:8080 -n airflow
# Open: http://localhost:8080
```

### Check Pod Health

```bash
kubectl get pods -n airflow

# Healthy state:
# airflow-scheduler    4/4  Running
# airflow-webserver    2/2  Running
# airflow-triggerer    3/3  Running
# airflow-statsd       1/1  Running
```

### Check Migration / Proxy Logs

```bash
# Cloud SQL proxy on scheduler
kubectl logs -n airflow \
  $(kubectl get pod -n airflow -l component=scheduler -o jsonpath='{.items[0].metadata.name}') \
  -c cloud-sql-proxy

# Git-sync logs
kubectl logs -n airflow \
  $(kubectl get pod -n airflow -l component=scheduler -o jsonpath='{.items[0].metadata.name}') \
  -c git-sync
```

### Overnight Shutdown (Save Money)

```bash
# Remove deletion protection, then destroy
gcloud sql instances patch {customer}-airflow-pg-dev --no-deletion-protection
cd terraform && terraform destroy -auto-approve
```

### Morning Restart

```bash
# Check if your IP changed
curl ifconfig.me

# If changed, update tfvars and apply
terraform apply -target=module.networking -auto-approve

# Remove stale state for manually deleted resources
terraform state rm module.gke.google_container_cluster.airflow_cluster
terraform state rm module.db.google_sql_database_instance.airflow_db

# Recreate
terraform apply -target=module.db  -auto-approve  # ~10 min
terraform apply -target=module.gke -auto-approve  # ~8 min

# Reconnect and redeploy
gcloud container clusters get-credentials {customer}-gke --region us-central1 --project PROJECT_ID
helm upgrade --install airflow apache-airflow/airflow \
  --namespace airflow --values helm/values.yaml --version 1.14.0 --timeout 15m
```

---

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `dial tcp X.X.X.X:443: i/o timeout` | VPN IP changed | `curl ifconfig.me` → update `authorized_vpn_cidr` in tfvars → `terraform apply -target=module.networking` |
| `403 NOT_AUTHORIZED` on cloud-sql-proxy | K8s SA missing WI binding | Re-run the `for KSA in...` loop in the deployment guide |
| Pods stuck in `Init:0/1` forever | Sidecar deadlock — init container waits for proxy that can't start | Add `waitForMigrations: enabled: false` to scheduler, webserver, triggerer in `values.yaml` → `helm upgrade` |
| `UPGRADE FAILED: another operation in progress` | Helm state lock | `kubectl delete secret -n airflow -l owner=helm,status=pending-install --ignore-not-found` |
| `Cannot modify allocated ranges in CreateConnection` | Duplicate VPC peering resources | `terraform state rm module.db.google_service_networking_connection.private_vpc_connection` → `terraform apply -target=module.db` |
| `No cluster named X in project Y` | Cluster deleted from UI but state still has it | `terraform state rm module.gke.google_container_cluster.airflow_cluster` → `terraform apply -target=module.gke` |
| `Invalid login` on Airflow UI | Admin user not created | Run the `airflow users create` kubectl exec command |
| `Blocks of type "secret_manager_config" not expected` | Wrong provider on GKE resource | Add `provider = google-beta` to `google_container_cluster` resource |
| `"workload_identity_config" conflicts with enable_autopilot` | Block is redundant on Autopilot | Remove `workload_identity_config` block from `gke/main.tf` entirely |

---

## Cost Reference

| Component | Dev/Month | Prod/Month | Notes |
|---|---|---|---|
| GKE Autopilot | ~$30-50 | ~$80-150 | Zero cost when no tasks running |
| Cloud SQL `db-g1-small` | ~$25 | ~$100 | Prod uses `db-custom-2-4096` + HA |
| Cloud NAT | ~$5 | ~$10 | ~$1/day + data transfer |
| GCS Logging | ~$1-3 | ~$5-10 | 80% saved via Coldline lifecycle |
| **Total (estimate)** | **~$60-80** | **~$200-300** | Highly variable with workload |

> **Biggest saving:** Delete Cloud SQL and GKE overnight. A running but idle cluster still costs money. Use `terraform destroy` at end of day.

---

## Security Model

| Control | How It's Implemented |
|---|---|
| No public node IPs | `enable_private_nodes = true` in GKE module |
| K8s API access restricted | `master_authorized_networks = VPN CIDR only` |
| No static GCP SA keys | Workload Identity — OIDC token exchange per request |
| Database not publicly accessible | Cloud SQL Private IP only (`ipv4_enabled = false`) |
| SSH keys never in repo | `.gitignore` + stored only in `~/.ssh/` locally |
| Container security | `runAsNonRoot: true` + `allowPrivilegeEscalation: false` |
| Cost guardrails | Spot workers + GCS lifecycle rules + Namespace quotas |

---

## Multi-Customer Deployments

Each customer is fully isolated in their own GCP project. To deploy for a new customer:

```bash
./deploy.sh \
  new-customer      \
  new-gcp-project   \
  dev               \
  $(curl -s ifconfig.me)/32 \
  NewCustomerPass2026 \
  git@github.com:new-customer/airflow-dags.git
```

Keep per-customer tfvars files:
```bash
# Save current state
cp terraform/terraform.tfvars terraform/terraform.tfvars.acme-corp

# Switch to a different customer
cp terraform/terraform.tfvars.globex terraform/terraform.tfvars
```

---

## Related Documentation

| Document | Description |
|---|---|
| `Airflow_GKE_Zero_To_Running_Guide.docx` | Complete from-scratch build guide with all Terraform code |
| `Airflow_GKE_Confluence_Guide.docx` | Architecture, IAM, networking, and ops reference |
| `DDL_Airflow_GKE_v2.docx` | Detailed Design Layout — full technical specification |
| `Remediation_Guide_airflow_iac.docx` | Gap analysis and fix guide for existing deployments |

---

## Contributing

1. All infrastructure changes go through Terraform — never click in the GCP Console
2. DAG Python files go in the separate `airflow-dags` repository, not here
3. Never commit `terraform.tfvars`, SSH keys, or `.terraform/` directories
4. Test changes in `dev` environment before applying to `prod`
5. Run `terraform validate` before every `terraform apply`