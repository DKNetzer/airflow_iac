/*resource "kubernetes_namespace" "airflow" {
  metadata {
    name = "airflow"
  }
}*/
# Step 1: GCP Service Account
resource "google_service_account" "airflow_worker" {
  account_id   = "${var.customer}-airflow-worker"
  display_name = "Airflow Worker Workload Identity SA"
  project      = var.project_id
}
 
# Step 2a: GCS logs access (scoped to logs bucket only)
resource "google_project_iam_member" "airflow_gcs_logs" {
  project = var.project_id
  role    = "roles/storage.objectAdmin"
  member  = "serviceAccount:${google_service_account.airflow_worker.email}"
}
 
# Step 2b: Cloud SQL client access
resource "google_project_iam_member" "airflow_cloudsql_client" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.airflow_worker.email}"
}
 
# Step 2c: Secret Manager access (scoped to git-sync key secret only)
resource "google_secret_manager_secret_iam_member" "git_sync_key_access" {
  secret_id = "${var.customer}-git-sync-ssh-key"
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.airflow_worker.email}"
  project   = var.project_id
}
 
# Step 3: Allow K8s SA to impersonate GCP SA (the WI binding)
resource "google_service_account_iam_member" "workload_identity_binding" {
  service_account_id = google_service_account.airflow_worker.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[airflow/airflow-worker]"
}
 
/*# Step 4: Kubernetes Service Account with GCP SA annotation
resource "kubernetes_service_account" "airflow_worker" {
  metadata {
    name      = "airflow-worker"
    namespace = "airflow"
    annotations = {
      "iam.gke.io/gcp-service-account" = google_service_account.airflow_worker.email
    }
  }
}*/
