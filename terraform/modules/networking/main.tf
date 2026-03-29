# 1. Custom VPC
resource "google_compute_network" "vpc" {
  name                    = "${var.customer}-vpc"
  auto_create_subnetworks = false
  project                 = var.project_id
}

# 2. Airflow Subnet
resource "google_compute_subnetwork" "subnet" {
  name                     = "${var.customer}-airflow-subnet"
  ip_cidr_range            = var.vpc_cidr
  region                   = var.region
  network                  = google_compute_network.vpc.id
  project                  = var.project_id
  private_ip_google_access = true
}

# 3. Cloud NAT (Allows private pods to reach GitHub)
resource "google_compute_router" "router" {
  name    = "${var.customer}-router"
  region  = var.region
  network = google_compute_network.vpc.id
  project = var.project_id
}

resource "google_compute_router_nat" "nat" {
  name                               = "${var.customer}-nat"
  router                             = google_compute_router.router.name
  region                             = var.region
  project                            = var.project_id
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}