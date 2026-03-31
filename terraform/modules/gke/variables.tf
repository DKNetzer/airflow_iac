variable "project_id"          { type = string }
variable "region"              { type = string }
variable "customer"            { type = string }
variable "network_id"          { type = string }
variable "subnet_id"           { type = string }
# ADD to terraform/modules/gke/variables.tf
variable "authorized_vpn_cidr" {
  description = "Corporate VPN CIDR allowed to reach the private K8s API."
  type        = string
}
# Add this one; it helps the Helm provider know when the cluster is ready
output "cluster_name" {
  value = google_container_cluster.airflow_cluster.name
}