resource "helm_release" "airflow" {
  name             = "airflow"
  repository       = "https://airflow.apache.org"
  chart            = "airflow"
  version          = "1.14.0"
  namespace        = "airflow"
  create_namespace = true
  timeout          = 600
  atomic           = false
  cleanup_on_fail  = true
 
  values = [
    templatefile("${path.module}/../helm/values.yaml", {
      project_id   = var.project_id
      customer     = var.customer
      environment  = var.environment
      region       = var.region
      dag_repo_url = var.dag_repo_url
    })
  ]
 
  depends_on = [
    module.gke,            # Reference the GKE module
    module.db,             # Reference the DB module
    module.iam,            # Assuming service accounts are here
    google_storage_bucket.airflow_logs # This is in root, so this stays same
  ]
}

