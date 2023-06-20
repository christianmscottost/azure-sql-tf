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
variable "names" {
    type = list(string)
    default = ["test", "test2", "test3"]
}
