locals {
  public_key       = "./.local/.ssh/id_rsa.pub"
}

provider libvirt {
  uri = "qemu:///system"
}

resource libvirt_pool local {
  name = "ubuntu"
  type = "dir"
  path = "${path.cwd}/volume_pool"
}

resource libvirt_volume ubuntu1804_cloud {
  name   = "ubuntu18.04.qcow2"
  pool   = libvirt_pool.local.name
  source = "https://cloud-images.ubuntu.com/bionic/current/bionic-server-cloudimg-amd64.img"
  format = "qcow2"
}

resource libvirt_volume ubuntu1804_resized {
  name           = "ubuntu-volume-${count.index}"
  base_volume_id = libvirt_volume.ubuntu1804_cloud.id
  pool           = libvirt_pool.local.name
  size           = 42949672960
  count          = 3
}

resource libvirt_cloudinit_disk cloudinit_ubuntu {
  name = "cloudinit_ubuntu_resized.iso"
  pool = libvirt_pool.local.name

  user_data = <<EOF
#cloud-config
disable_root: 0
ssh_pwauth: 1
users:
  - name: ubuntu
    shell: /bin/bash
    sudo: ALL=(ALL) NOPASSWD:ALL
    ssh-authorized-keys:
      - ${file(local.public_key)}
growpart:
  mode: auto
  devices: ['/']
EOF

}

resource libvirt_network kube_network {
  name      = "k8snet"
  mode      = "nat"
  domain    = "k8s.local"
  addresses = ["172.16.1.0/24"]
  dns {
    enabled = true
  }
}


resource libvirt_domain k8s_master {
  name   = "k8s-master"
  memory = "4096"
  vcpu   = 2

  cloudinit = libvirt_cloudinit_disk.cloudinit_ubuntu.id

  network_interface {
    network_id     = libvirt_network.kube_network.id
    hostname       = "k8s-master"
    addresses      = ["172.16.1.11"]
    wait_for_lease = true
  }

  disk {
    volume_id = libvirt_volume.ubuntu1804_resized[0].id
  }

  console {
    type        = "pty"
    target_type = "serial"
    target_port = "0"
  }

  graphics {
    type        = "spice"
    listen_type = "address"
    autoport    = true
  }
}

resource libvirt_domain k8s_worker_1 {
  name   = "k8s-worker-1"
  memory = "2048"
  vcpu   = 2

  cloudinit = libvirt_cloudinit_disk.cloudinit_ubuntu.id

  network_interface {
    network_id     = libvirt_network.kube_network.id
    hostname       = "k8s-worker-1"
    addresses      = ["172.16.1.21"]
    wait_for_lease = true
  }

  disk {
    volume_id = libvirt_volume.ubuntu1804_resized[1].id
  }

  console {
    type        = "pty"
    target_type = "serial"
    target_port = "0"
  }

  graphics {
    type        = "spice"
    listen_type = "address"
    autoport    = true
  }
}

resource libvirt_domain k8s_worker_2 {
  name   = "k8s-worker-2"
  memory = "2048"
  vcpu   = 2

  cloudinit = libvirt_cloudinit_disk.cloudinit_ubuntu.id

  network_interface {
    network_id     = libvirt_network.kube_network.id
    hostname       = "k8s-worker-2"
    addresses      = ["172.16.1.22"]
    wait_for_lease = true
  }

  disk {
    volume_id = libvirt_volume.ubuntu1804_resized[2].id
  }

  console {
    type        = "pty"
    target_type = "serial"
    target_port = "0"
  }

  graphics {
    type        = "spice"
    listen_type = "address"
    autoport    = true
  }
}
