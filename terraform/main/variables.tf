variable "token" {
  type = string
}

variable "cloud_id" {
  type = string
}

variable "folder_id" {
  type = string
}

variable "zone" {
  default = "ru-central1-a"
}

variable "cidr" {
  default = "10.0.1.0/24"
}

variable "vpc_name" {
  default = "develop"
}

variable "public_key" {
  type = string
}

variable "ubuntu_image" {
  default = "fd8136cthbfr503tjj72"
}