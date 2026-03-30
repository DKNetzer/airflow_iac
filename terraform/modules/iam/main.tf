# DDL Section 6: Airflow Service Account
resource "google_service_account" "airflow_sa" {
  account_id   = "${var.customer}-airflow-sa"
  display_name = "Service Account for Airflow Pods"
  project      = var.project_id
}

# Allow GKE Workload Identity to "impersonate" this service account
# This assumes we will deploy Airflow in the 'default' namespace
resource "google_service_account_iam_member" "workload_identity_user" {
  service_account_id = google_service_account.airflow_sa.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[default/airflow-worker]"
}

# DDL Section 7: Allow this SA to read secrets
resource "google_project_iam_member" "secret_reader" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.airflow_sa.email}"
}

# DDL Section 4: Allow SA to connect to Cloud SQL
resource "google_project_iam_member" "sql_client" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.airflow_sa.email}"
}
