variable "project_id"    { type = string }
variable "region"        { type = string }
variable "customer"      { type = string }
variable "environment"   { type = string }
variable "network_id"    { type = string }
variable "cloud_sql_tier" {
  type    = string
  default = "db-g1-small"
}

# db_password intentionally removed — IAM auth only

