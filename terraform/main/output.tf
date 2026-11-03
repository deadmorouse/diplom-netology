output "nodes" {
  value = [
    for i in yandex_compute_instance.platform :
    "name=${i.name} external=${i.network_interface.0.nat_ip_address}"
  ]
}