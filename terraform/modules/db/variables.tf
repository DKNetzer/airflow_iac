variable "project_id" {}
variable "region"     {}
variable "customer"   {}
variable "network_id" {}

variable "db_password" {
  type      = string
  sensitive = true
}
