variable "service" {
  default = "sql"
}
variable "environment" {}
variable "region" {
  default = {
    name   = "East US"
    suffix = "eus"
  }
}
