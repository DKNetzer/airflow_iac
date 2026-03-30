variable "project_id" { type = string }
variable "region"     { type = string }
variable "customer"   { type = string }

variable "authorized_vpn_cidr" {
  type        = string
  description = "DDL Section 3: The authorized VPN range for K8s API access"
}
