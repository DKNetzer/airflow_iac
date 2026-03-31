# Required for Cloud SQL Private IP — must exist before the DB instance
resource "google_compute_global_address" "private_ip_range" {
  name          = "${var.customer}-sql-private-range"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = var.network_id
}

resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = var.network_id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_range.name]
}

resource "google_sql_database_instance" "airflow_db" {
  name             = "${var.customer}-airflow-pg-${var.environment}"
  database_version = "POSTGRES_15"
  region           = var.region
  deletion_protection = true   # Prevents accidental terraform destroy
 
  settings {
    tier              = var.cloud_sql_tier
    availability_type = var.environment == "prod" ? "REGIONAL" : "ZONAL"
 
    ip_configuration {
      ipv4_enabled    = false
      private_network = var.network_id
      enable_private_path_for_google_cloud_services = true
    }
 
    database_flags {
      name  = "cloudsql.iam_authentication"
      value = "on"
    }
 
    backup_configuration {
      enabled                        = true
      start_time                     = "02:00"
      point_in_time_recovery_enabled = var.environment == "prod" ? true : false
      transaction_log_retention_days = var.environment == "prod" ? 7 : 1
      backup_retention_settings {
        retained_backups = var.environment == "prod" ? 30 : 7
        retention_unit   = "COUNT"
      }
    }
  }
  depends_on = [google_service_networking_connection.private_vpc_connection]
 } 
resource "google_sql_database" "airflow" {
  name     = "airflow"
  instance = google_sql_database_instance.airflow_db.name
}