resource "google_container_cluster" "primary" {
  name     = "${var.customer}-airflow-cluster"
  location = var.region

  enable_autopilot = true # DDL Requirement
  
  network    = var.network_id
  subnetwork = var.subnet_id

  # DDL Section 5.1: Private Cluster Config
  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false
    master_ipv4_cidr_block  = "172.16.0.0/28"
  }

  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }
}
