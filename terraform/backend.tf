terraform {
  backend "local" {
    path = "terraform.tfstate"
  }
}

# Para usar S3 backend, comenta el backend local de arriba y descomenta esto:
# terraform {
#   backend "s3" {
#     bucket  = "terraform-state-olcb"
#     key     = "pid-control/terraform.tfstate"
#     region  = "eu-west-1"
#     encrypt = true
#   }
# }
