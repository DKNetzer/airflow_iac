variable "project_id" {
  description = "The GCP Project ID for all resources."
  type        = string
}
 
variable "region" {
  description = "Primary GCP region."
  type        = string
  default     = "us-central1"
}
 
variable "customer" {
  description = "Customer/tenant slug. Used in all resource names."
  type        = string
}
 
variable "environment" {
  description = "Deployment environment: dev or prod."
  type        = string
  validation {
    condition     = contains(["dev","prod"], var.environment)
    error_message = "environment must be dev or prod."
  }
}
 
variable "authorized_vpn_cidr" {
  description = "Corporate VPN CIDR allowed to reach the private K8s API."
  type        = string
}
 
variable "enable_spot_workers" {
  description = "Toggle Spot instances for worker pods (60-90% cost saving)."
  type        = bool
  default     = true
}
 
variable "dag_repo_url" {
  description = "SSH URL of the GitHub repo containing DAGs."
  type        = string
}
 
variable "cloud_sql_tier" {
  description = "Cloud SQL tier. db-g1-small for dev, db-custom-2-4096 for prod."
  type        = string
  default     = "db-g1-small"
}
 
# NOTE: db_password has been intentionally removed.
# Access is granted via IAM Database Authentication — no password ever needed.
