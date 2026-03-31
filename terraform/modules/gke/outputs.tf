output "endpoint" {
  value = google_container_cluster.airflow_cluster.endpoint
}

output "ca_certificate" {
  value = google_container_cluster.airflow_cluster.master_auth[0].cluster_ca_certificate
}