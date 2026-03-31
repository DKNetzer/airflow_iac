resource "google_container_cluster" "airflow_cluster" {
  name     = "${var.customer}-gke"
  location = var.region
  project  = var.project_id
 
  enable_autopilot = true
 
  release_channel {
    channel = "REGULAR"   # Stable cadence; avoid RAPID for production
  }
 
  # PRIVATE CLUSTER — K8s API only reachable from Corporate VPN
  private_cluster_config {
    enable_private_nodes    = true    # Nodes have no public IPs
    enable_private_endpoint = false   # API reachable from VPN-whitelisted CIDR
    master_ipv4_cidr_block  = "172.16.0.0/28"
  }
 
  master_authorized_networks_config {
    cidr_blocks {
      cidr_block   = var.authorized_vpn_cidr
      display_name = "Corporate VPN"
    }
  }
 
  network    = var.network_id
  subnetwork = var.subnet_id
 
  ip_allocation_policy {
    cluster_secondary_range_name  = "gke-pods"     # FIX: explicit secondary ranges
    services_secondary_range_name = "gke-services"
  }
 
 # workload_identity_config {
  #  workload_pool = "${var.project_id}.svc.id.goog"
  #}
 
 # secret_manager_config {
   # enabled = true   # Native Secret Manager CSI driver
  #}
 
  datapath_provider = "ADVANCED_DATAPATH"   # Enables Dataplane V2 + NetworkPolicy
}
