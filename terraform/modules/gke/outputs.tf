output "endpoint" {
  description = "The IP address of the cluster master"
  value       = google_container_cluster.primary.endpoint
}

output "ca_certificate" {
  description = "The public certificate of the cluster master"
  value       = google_container_cluster.primary.master_auth[0].cluster_ca_certificate
}