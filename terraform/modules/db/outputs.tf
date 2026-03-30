output "db_instance_name" {
  value = google_sql_database_instance.airflow_db.name
}

output "db_private_ip" {
  value = google_sql_database_instance.airflow_db.private_ip_address
}
