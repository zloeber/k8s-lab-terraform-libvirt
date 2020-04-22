
output master_ip {
  value = libvirt_domain.k8s_masters[0].network_interface[0].addresses[0]
}

output worker_1_ip {
  value = libvirt_domain.k8s_workers[0].network_interface[0].addresses[0]
}

output worker_2_ip {
  value = libvirt_domain.k8s_workers[1].network_interface[0].addresses[0]
}
