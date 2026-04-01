# ==============================================================================
# DDL SECTION 1: TERRAFORM CONFIGURATION & BACKEND
# ==============================================================================

# AFTER (DDL-compliant)
terraform {
  required_version = ">= 1.7.0"
  backend "gcs" {
    bucket = "tf-state-${var.customer}-airflow"
    prefix = "terraform/state"
  }
  required_providers {
    google      = { source = "hashicorp/google",      version = "~> 5.25.0" }
    google-beta = { source = "hashicorp/google-beta", version = "~> 5.25.0" }
    kubernetes  = { source = "hashicorp/kubernetes",  version = "~> 2.29.0" }
    helm        = { source = "hashicorp/helm",        version = "~> 2.13.0" }
  }
}


# ==============================================================================
# DDL SECTION 1 & 12: PROVIDERS & SERVICES
# ==============================================================================
provider "google" {
  project = var.project_id
  region  = var.region
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
}

# DDL Section 12: Ensure mandatory APIs are enabled
resource "google_project_service" "compute" {
  service            = "compute.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "container" {
  service            = "container.googleapis.com"
  disable_on_destroy = false
}

# DDL Section 5.3: Dynamic Kubernetes & Helm Authentication
# This fetches a fresh OAuth2 token from Google to talk to the K8s API
data "google_client_config" "default" {}

provider "kubernetes" {
 host                   = "https://${module.gke.endpoint}"
 token                  = data.google_client_config.default.access_token
 cluster_ca_certificate = base64decode(module.gke.ca_certificate)
}

provider "helm" {
  kubernetes {
    host                   = "https://${module.gke.endpoint}"
    token                  = data.google_client_config.default.access_token
    cluster_ca_certificate = base64decode(module.gke.ca_certificate)
  }
}

resource "google_project_service" "secretmanager" {
  service            = "secretmanager.googleapis.com"
  disable_on_destroy = false
}
resource "google_project_service" "servicenetworking" {
  service            = "servicenetworking.googleapis.com"
  disable_on_destroy = false
}
resource "google_project_service" "sqladmin" {
  service            = "sqladmin.googleapis.com"
  disable_on_destroy = false
}
resource "google_project_service" "iam" {
  service            = "iam.googleapis.com"
  disable_on_destroy = false
}


# ==============================================================================
# DDL SECTION 3: NETWORKING FOUNDATION
# ==============================================================================
module "networking" {
  source              = "./modules/networking"
  project_id          = var.project_id
  region              = var.region
  customer            = var.customer
  authorized_vpn_cidr = var.authorized_vpn_cidr
}

# ==============================================================================
# DDL SECTION 5: GKE CLUSTER LAYER (AUTOPILOT)
# ==============================================================================
module "gke" {
  source              = "./modules/gke"
  project_id          = var.project_id
  region              = var.region
  customer            = var.customer
  network_id          = module.networking.network_id
  subnet_id           = module.networking.subnet_id
  authorized_vpn_cidr = var.authorized_vpn_cidr   # ADD THIS LINE
  depends_on = [module.networking]
}


module "db" {
  source                    = "./modules/db"
  project_id                = var.project_id
  region                    = var.region
  customer                  = var.customer
  environment               = var.environment
  network_id                = module.networking.network_id
  cloud_sql_tier            = var.cloud_sql_tier
  private_vpc_connection_id = module.networking.private_vpc_connection_id
}


module "iam" {
  source     = "./modules/iam"
  project_id = var.project_id
  customer   = var.customer
}