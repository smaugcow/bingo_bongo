output "container_registry_id" {
  value = yandex_container_registry.registry-bingo.id
}

output "external_db_ip" {
  value = yandex_compute_instance.bingo-db.network_interface[0].nat_ip_address
}

output "external_vms_ip" {
  value = [yandex_compute_instance_group.bingo.instances[*].network_interface[0].nat_ip_address]
}

output "external_load_balancer_ip" {
  value = yandex_lb_network_load_balancer.lb-bingo.listener.*.external_address_spec[0].*.address
}
