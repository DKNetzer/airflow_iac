# DDL Section 4.1: Private Service Connection (Required for Private IP SQL)
resource "google_compute_global_address" "private_ip_address" {
  name          = "${var.customer}-sqldb-peering"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = var.network_id
}

resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = var.network_id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_address.name]
}

# DDL Section 4.2: Cloud SQL Instance
resource "google_sql_database_instance" "airflow_db" {
  name             = "${var.customer}-airflow-db"
  database_version = "POSTGRES_15"
  region           = var.region
  
  # Ensures the peering is established before the DB tries to join
  depends_on = [google_service_networking_connection.private_vpc_connection]

  settings {
    tier = "db-f1-micro" # <--- MONEY SAVER: Cheapest tier for dev/prod-start
    
    ip_configuration {
      ipv4_enabled    = false        # No Public IP (Saves money & increases security)
      private_network = var.network_id
    }

    backup_configuration {
      enabled = true
    }
  }
}

resource "google_sql_user" "airflow_user" {
  name     = "airflow"
  instance = google_sql_database_instance.airflow_db.name
  password = var.db_password
}
