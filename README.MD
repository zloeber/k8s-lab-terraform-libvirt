# Libvirt/Terraform K8s Lab Environment

## Purpose

This is meant to be a one stop location for studying for the CKA exam where you can bring up a multi-node lab locally with minimal effort and start practicing your Kubernetes kung-fu. This lab will kickstart your nodes up to the point where you need to get them clustered via kubeadm.

## Requirements

This uses the libvirt provider for terraform which, as far as I can see, only creates prebuilt binaries for Linux. As such, Linux as your base host is a requirement.

I got this all running using Qemu as the backing provider for libvirt. I also used the Ubuntu release version of the libvirt terraform provider (this can be changed in the init.sh script to some other supported Distro though). As such an Ubuntu based host should be used. You will also want to ensure that the folder you cloned this repo to is on a disk with plenty of space and a host that can accommodate the three VMs that will get spun up.

We need a few base apps and utilities (probably more than this needs to be installed, sorry if the base list of packages isn't 100% correct)

```bash
sudo apt install libvirt-clients libvirt-daemon qemu tmux genisoimage
```

Your account must have access to manage libvirt resources as well this should get you started.

```bash
sudo usermod -a -G libvirt $(whoami)
newgrp libvirt
```
We need to manually pull in the most recent libvirt terraform provider plugin and create an ssh key for use in the deployment. You can do all of this easily enough with a quick make task.

```bash
make deps
```

## The Lab

This lab consists of 3 virtual machines with the following names and specifications:

| Node | vCPUS | RAM | Disk | IP |
|---|---|---|---|---|
| k8s-master-1 | 2 | 4GB | 40GB | 172.16.1.11/24 |
| k8s-worker-1 | 2 | 2GB | 40GB | 172.16.1.21/24 |
| k8s-worker-2 | 2 | 2GB | 40GB | 172.16.1.22/24 |

```bash
# If all the dependencies are in place then initialize, plan, and apply the terraform manifest to bring things up.
make init plan create

# Destroy just as easily.
make destroy

# Access the master node
make ssh/master

# or the worker nodes
make ssh/worker1
make ssh/worker2

# or all the nodes at once with synchronized input
make ssh/all
```

You can increase the number of master/worker nodes by updating the variables at the top of the main.tf file. The Makefile was only setup to work with the three nodes though as that's all you really need for most basic lab environments.

If you need to update/change the Kubernetes component versions please update the main.tf variables.

**NOTE:** When you bring the lab up for the first time it may take a few minutes to install docker and become fully ready for a Kubernetes installation.

## Cloud Init

The cloud_init.cfg template is used to provide an initial configuration for the instances. This includes;

- Setting the local hostname (important for the cluster to work properly)
- Adding the docker repo and gpg key
- Adding the kubernetes repo and gpg key
- Installing some initial required packages common to all nodes
- Configure the default user (ubuntu) with passwordless sudo rights.
- Install containerd.io, docker-ce, docker-ce-cli, kubelet, kubeadm, and kubectl (and put kube* marked for hold)
- Deploy docker service as a daemon

See the cloud_init.cfg for further information or to customize the deployment further.

## Extras

There are some additional configuration tasks that you can use to shortcut a cluster setup found in the `tasks/1-deploy-kubernetes.md` documentation.

If you are brave and are using asdf-vm along with direnv you may also be able to use the included ansible playbook to deploy your cluster even more quickly. This assumes that the direnv Python virtual environment got setup correctly and that asdf is also working. The original playbook (see link in references) was modified to not install docker and does not do any additional deployment beyond the calico CNI setup and node joins via kubeadm. Nor has any other CNI been tested.

```bash
make cluster/deploy
make kube/export/config
```

It wouldn't be too hard to dissect the makefile task to run this playbook manually of course.

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

## Exam Tips

Here are a few random tips which may or may not help you on exam day.

**kubectl explain**

Using `kubectl explain` will show more information on just about everything you may be authoring in YAML manfiests. The format is: `<resource>.<group>.<property>` for individual properties. Or you can get all available properties by omitting the `.<property>`. With some creativity and the `--recursive=true` flag you can get somthing that looks almost like a YAML snippet.

```bash
# Show all available properties for pod.spec
kubectl explain pod.spec | grep '<'

# Show all available properties for deployment.spec.template.spec.containers
kubectl explain deployment.spec.template.spec.containers --recursive=true | grep '<' 
```

## Links

[CKA Practice Excercises](https://github.com/alijahnas/CKA-practice-exercises) (initial source of the terraform manifest and a great study guide!)

[Additional CKA Study Repo 1](https://github.com/walidshaari/Kubernetes-Certified-Administrator)

[Additional CKA Study Repo 2](https://github.com/dgkanatsios/CKAD-exercises)

[A Great CKA Study Guide](http://www.kubernet.io/)

[Libvirt Terraform Provider](https://github.com/dmacvicar/terraform-provider-libvirt)

[xpanes for tmux](https://github.com/greymd/tmux-xpanes)

[Cloud Init Examples](https://cloudinit.readthedocs.io/en/latest/topics/examples.html)

[kubeadm via Ansible](https://github.com/kairen/kubeadm-ansible)
