terraform {
  required_version = ">= 1.5.0"

  # Secure Backend for State Locking
  # Note: Variables are not allowed in the backend block
  backend "gcs" {
    bucket = "tf-state-dkn-airflow"
    prefix = "terraform/state"
  }

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.10.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 5.10.0"
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

# Standard Provider
provider "google" {
  project = var.project_id
  region  = var.region
}

# Beta Provider (Required for certain Autopilot & Secret Manager features)
provider "google-beta" {
  project = var.project_id
  region  = var.region
}

# Phase 2: The Networking Foundation
module "networking" {
  source         = "./modules/networking"
  project_id     = var.project_id
  region         = var.region
  customer       = var.customer
  # CIDRs matching our DDL specification
  vpc_cidr       = "10.10.0.0/20"
  peering_cidr   = "10.13.0.0/28" 
}