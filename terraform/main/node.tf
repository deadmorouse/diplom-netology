resource "yandex_compute_instance" "platform" {
  count = 3

  name        = "node-${count.index}"
  hostname    = "node-${count.index}"
  zone        = var.zone
  platform_id = "standard-v3"

  allow_stopping_for_update = true

  resources {
    cores         = 4
    memory        = 4
    core_fraction = 20
  }

  boot_disk {
    initialize_params {
      image_id = var.ubuntu_image
      size     = 30
    }
  }

  scheduling_policy {
    preemptible = true
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.develop_subnet.id
    nat       = true
  }

  metadata = {
    serial-port-enable = 1
    ssh-keys           = "ubuntu:${var.public_key}"
  }
}