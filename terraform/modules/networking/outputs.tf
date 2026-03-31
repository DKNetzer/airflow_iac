# DDL Section 3: Exporting IDs for the GKE Module
output "network_id" {
  description = "The ID of the VPC"
  value       = google_compute_network.airflow_vpc.id # Matches your resource name
}

output "subnet_id" {
  description = "The ID of the Airflow subnet"
  value       = google_compute_subnetwork.airflow_subnet.id # Matches your resource name
}

output "private_network_connection_id" {
  value = google_service_networking_connection.private_vpc_connection.id
}