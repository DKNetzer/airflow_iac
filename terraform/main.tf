# ==============================================================================
# DDL SECTION 1: TERRAFORM CONFIGURATION & BACKEND
# ==============================================================================
terraform {
  required_version = ">= 1.5.0"

  backend "gcs" {
    bucket = "tf-state-dkn-airflow"
    prefix = "terraform/state"
  }

  required_providers {
    google = {
      source  = "hashicorp/google"
      # DDL Requirement: Using 5.45.2 for latest Autopilot features
      version = "~> 5.45.2" 
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 5.45.2"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.24.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12.0"
    }
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
  kubernetes = {
    host                   = "https://${module.gke.endpoint}"
    token                  = data.google_client_config.default.access_token
    cluster_ca_certificate = base64decode(module.gke.ca_certificate)
  }
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
  source     = "./modules/gke"
  project_id = var.project_id
  region     = var.region
  customer   = var.customer
  network_id = module.networking.network_id
  subnet_id  = module.networking.subnet_id
}

module "db" {
  source      = "./modules/db"
  project_id  = var.project_id
  region      = var.region
  customer    = var.customer
  network_id  = module.networking.network_id
  db_password = var.db_password # Define this in your root variables.tf
}

module "iam" {
  source     = "./modules/iam"
  project_id = var.project_id
  customer   = var.customer
}