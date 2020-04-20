
output master_ip {
  value = libvirt_domain.k8s_master.network_interface[0].addresses[0]
}

output worker_1_ip {
  value = libvirt_domain.k8s_worker_1.network_interface[0].addresses[0]
}

output worker_2_ip {
  value = libvirt_domain.k8s_worker_2.network_interface[0].addresses[0]
}
