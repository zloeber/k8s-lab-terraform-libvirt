# Libvirt/Terraform K8s Lab Environment

## Requirements

This uses the libvirt provider for terraform which, as far as I can see, only creates prebuilt binaries for Linux variants. As such Linux as a base host is required.

I got this all running using Qemu as the backing provider for libvirt. I also used the Ubuntu release version of the libvirt terraform provider (this can be changed in the init.sh script to some other supported Distro though). As such an Ubuntu based host should be used. You will also want to ensure that the folder you cloned this repo to is on a disk with plenty of space and a host that can accommodate the three VMs that will get spun up.

We need a few base apps and utilities (probably more than this needs to be installed, sorry if the base list of packages isn't 100% correct)

```bash
sudo apt install libvirt-clients libvirt-daemon qemu tmux genisoimage
```

Your account must have access to manage libvirt resources as well

```bash
sudo usermod -a -G libvirt $(whoami)
newgrp libvirt
```

~~Within this cloned repo you should create the libvirt storage pool (this is important as you will want to ensure that you have enough disk space to accomodate the VMs)~~ The volume pool creation/destruction is now part of the terraform manifest. 

We need to manually pull in the most recent libvirt terraform provider plugin and create an ssh key for use in the deployment. You can do all of this easily enough with a quick make task.

```bash
make deps
```

## The Lab

This lab consists of 3 virtual machines with the following names and specifications:

| Node | vCPUS | RAM | Disk | IP |
|---|---|---|---|---|
| k8s-master | 2 | 4GB | 40GB | 172.16.1.11/24 |
| k8s-worker-1 | 2 | 2GB | 40GB | 172.16.1.21/24 |
| k8s-worker-2 | 2 | 2GB | 40GB | 172.16.1.22/24 |

```bash
# If all the dependencies are in place then initialize, plan, and apply the terraform manifest to bring things up.
make init plan create

# Destroy just as easily.
make destroy

# Access the master node
make ssh-master

# or the worker nodes
make ssh-worker1
make ssh-worker2

# or all the nodes at once with synchronized input
make ssh-all
```

## Cloud Init

The cloud_init.cfg template is used to provide an initial configuration for the instances. This includes;

- Adding the docker repo and gpg key
- Adding the kubernetes repo and gpg key
- Installing some initial required packages common to all nodes
- Configure the default user (ubuntu) with passwordless sudo rights.

What is still left to do (this can be done via copy/paste after running `make ssh-all` to deploy to all nodes)

```bash
# Install docker and kube tools
sudo apt-get install -y \
  containerd.io=1.2.10-3 \
  docker-ce=5:19.03.4~3-0~ubuntu-$(lsb_release -cs) \
  docker-ce-cli=5:19.03.4~3-0~ubuntu-$(lsb_release -cs) \
  kubelet=1.17.5-00 kubeadm=1.17.5-00 kubectl=1.17.5-00
sudo apt-mark hold kubelet kubeadm kubectl

# Setup docker daemon.
cat << EOF | sudo tee /etc/docker/daemon.json
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2"
}
EOF

sudo mkdir -p /etc/systemd/system/docker.service.d
sudo systemctl daemon-reload
sudo systemctl restart docker
```

Finally, I couldn't figure out how to force the cloud config to update the hostnames properly so they all end up with the name of 'ubuntu'. Unfortunately the only work-around at the moment is to manually set them at each VM.

```bash
# On k8s-master
sudo hostnamectl set-hostname k8s-master
sudo reboot

# On k8s-worker-1
sudo hostnamectl set-hostname k8s-worker-1
sudo reboot

# On k8s-worker-2
sudo hostnamectl set-hostname k8s-worker-2
sudo reboot
```

## Issues

On Ubuntu distros SELinux is enforced by qemu even if it is disabled globally, this might cause unexpected Could not open '/var/lib/libvirt/images/<FILE_NAME>': Permission denied errors. Double check that security_driver = "none" is uncommented in /etc/libvirt/qemu.conf and issue sudo systemctl restart libvirt-bin to restart the daemon. [source](https://github.com/dmacvicar/terraform-provider-libvirt/issues/546)

I also had to do some things found [here](https://github.com/jedi4ever/veewee/issues/996) to get this resolved,

```bash
sudo groupadd --system libvirt
sudo usermod -a -G libvirt $(whoami)
newgrp libvirt
id $(whoami)
sudo systemctl stop libvirtd.service
sudo nano /etc/libvirt/qemu.conf
sudo echo "user = `whoami`" >> /etc/libvirt/qemu.conf
sudo echo "group = `whoami`" >> /etc/libvirt/qemu.conf
sudo systemctl start libvirtd.service
```

## Links

[Libvirt Terraform Provider](https://github.com/dmacvicar/terraform-provider-libvirt)

[CKA Practice Excercises](https://github.com/alijahnas/CKA-practice-exercises) (initial source of the terraform manifest and a great study guide!)

[xpanes for tmux](https://github.com/greymd/tmux-xpanes)

[Cloud Init Examples](https://cloudinit.readthedocs.io/en/latest/topics/examples.html)
