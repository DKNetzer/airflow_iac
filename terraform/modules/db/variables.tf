variable "project_id"    { type = string }
variable "region"        { type = string }
variable "customer"      { type = string }
variable "environment"   { type = string }
variable "network_id"    { type = string }
variable "cloud_sql_tier" {
  type    = string
  default = "db-g1-small"
}
variable "private_vpc_connection_id" {
  description = "ID of the VPC peering connection from the networking module. Used to enforce depends_on ordering."
  type        = string
}