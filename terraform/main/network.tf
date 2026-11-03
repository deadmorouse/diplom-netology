resource "yandex_vpc_network" "develop" {
  name = var.vpc_name
}

resource "yandex_vpc_subnet" "develop_subnet" {
  name           = "subnet-a"
  zone           = var.zone
  network_id     = yandex_vpc_network.develop.id
  v4_cidr_blocks = [var.cidr]
}