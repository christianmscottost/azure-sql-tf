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
variable "repo" {}
variable "sku" {
  default = "standard"
}
