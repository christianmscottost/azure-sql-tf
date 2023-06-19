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
variable "names" {
    type = list(string)
    default = ["test", "test2", "test3"]
}
variable "sku" {
  default = "standard"
}
variable "kv-secret" {
    default = "secret"
  
}