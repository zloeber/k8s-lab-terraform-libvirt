
## Requirements

This uses libvirt and requires qemu to deploy. I also specifically use the Ubuntu version of the libvirt terraform provider (this can be changed in the init.sh script to some other supported Distro though). As such an Ubuntu based host should be used. You will also want to ensure that the folder you cloned this repo to is on a disk with plenty of space and a host that can accommodate the [lab infrastructure](#The-Lab)



We need a few apps and utilities (probably more than this though, sorry if the base list of packages isn't 100% correct)

```bash
sudo apt install libvirt-clients libvirt-daemon qemu
```

Your account must have access to manage libvirt resources

```bash
sudo usermod -a -G libvirt $(whoami)
newgrp libvirt
```

Within this cloned repo you should create the libvirt storage pool (this is important as you will want to ensure that you have enough disk space to accomodate the VMs). We also need to manually pull in the most recent libvirt terraform provider plugin and create an ssh key for use in the deployment. You can do all of this easily enough with a quick make task.

```bash
make deps
```

## The Lab

This lab consists of 3 virtual machines with the following names and specifications:

| Node | vCPUS | RAM | Disk | IP |
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
make ssh-worker-1
make ssh-worker-2
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