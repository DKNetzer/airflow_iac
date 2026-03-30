# DDL Section 3.1: VPC
resource "google_compute_network" "airflow_vpc" {
  name                    = "${var.customer}-airflow-vpc"
  auto_create_subnetworks = false 
  routing_mode            = "REGIONAL"
  project                 = var.project_id
}

# DDL Section 3.1: Subnet with secondary ranges for GKE Autopilot
resource "google_compute_subnetwork" "airflow_subnet" {
  name                     = "${var.customer}-airflow-subnet"
  ip_cidr_range            = "10.10.0.0/20"
  region                   = var.region
  network                  = google_compute_network.airflow_vpc.id
  project                  = var.project_id
  private_ip_google_access = true

  secondary_ip_range {
    range_name    = "gke-pods"
    ip_cidr_range = "10.20.0.0/16"
  }
  secondary_ip_range {
    range_name    = "gke-services"
    ip_cidr_range = "10.30.0.0/20"
  }
}

# DDL Section 3.1: Cloud NAT Router
resource "google_compute_router" "nat_router" {
  name    = "${var.customer}-nat-router"
  region  = var.region
  network = google_compute_network.airflow_vpc.id
  project = var.project_id
}

# DDL Section 3.1: Cloud NAT
resource "google_compute_router_nat" "cloud_nat" {
  name                               = "${var.customer}-cloud-nat"
  router                             = google_compute_router.nat_router.name
  region                             = var.region
  project                            = var.project_id
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
  min_ports_per_vm                   = 4096 # DDL FIX for parallel load
}

# DDL Section 3.1: Firewall
resource "google_compute_firewall" "allow_vpn_to_master" {
  name    = "${var.customer}-allow-vpn-master"
  network = google_compute_network.airflow_vpc.id
  project = var.project_id

  allow {
    protocol = "tcp"
    ports    = ["443"]
  }

  source_ranges = [var.authorized_vpn_cidr]
}