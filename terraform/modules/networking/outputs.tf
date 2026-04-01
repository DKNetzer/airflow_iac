# DDL Section 3: Exporting IDs for the GKE Module
output "network_id" {
  value = google_compute_network.airflow_vpc.id
}

output "subnet_id" {
  value = google_compute_subnetwork.airflow_subnet.id
}

output "private_vpc_connection_id" {
  value = google_service_networking_connection.private_vpc_connection.id
}