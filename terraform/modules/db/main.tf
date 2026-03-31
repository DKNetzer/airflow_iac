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
 } 
resource "google_sql_database" "airflow" {
  name     = "airflow"
  instance = google_sql_database_instance.airflow_db.name
}