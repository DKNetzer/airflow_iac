variable "project_id" {
  type        = string
  description = "The GCP Project ID"
}

variable "region" {
  type        = string
  default     = "us-central1"
  description = "GCP Region for all resources"
}

variable "customer" {
  type        = string
  description = "Customer name used for resource naming (e.g., dkn)"
}

variable "authorized_ips" {
  type        = string
  description = "Public CIDR (VPN/Office IP) allowed to access GKE Master API"
}