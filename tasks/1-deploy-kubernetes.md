**TASKS**

- Deploy Kubernetes via kubeadm

<details><summary>Solution</summary>
<p>

There are two deployment paths below, one for flannel and another for calico. The only difference between them is the default pod network passed in at the kubeadm init step. Both work well and are on the exam. Calico should be used if you are going to be testing out pod security policies.

```bash
## Flannel based cluster deployment

make ssh/master

# Deploy initial master
sudo kubeadm init --pod-network-cidr=10.244.0.0/16

# Configure kubectl access
mkdir -p $HOME/.kube
sudo mkdir -p /root/.kube
sudo cp -i /etc/kubernetes/admin.conf /root/.kube/config
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# Deploy Flannel as a network plugin
kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/2140ac876ef134e0ed5af15c65e414cf26827915/Documentation/kube-flannel.yml
```

```bash
## Alternatively, a calico based deployment

make ssh/master

# Deploy initial master
sudo kubeadm init --pod-network-cidr=192.168.0.0/16

# Configure kubectl access
mkdir -p $HOME/.kube
sudo mkdir /root/.kube
sudo cp -i /etc/kubernetes/admin.conf /root/.kube/config
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

kubectl apply -f https://docs.projectcalico.org/v3.11/manifests/calico.yaml
```
Copy the output from the first step and deploy to the other nodes using something like this:

```bash
make ssh/worker1
sudo kubeadm join 172.16.1.11:6443 --token xqckqj.2j6umqdoe416ra9p --discovery-token-ca-cert-hash sha256:6701e97f40377b98e0ae2d35add6ada9050158ab876f9669b22ff09dedae8897
exit

make ssh/worker2
sudo kubeadm join 172.16.1.11:6443 --token xqckqj.2j6umqdoe416ra9p --discovery-token-ca-cert-hash sha256:6701e97f40377b98e0ae2d35add6ada9050158ab876f9669b22ff09dedae8897
exit
```

Then validate on the master node that all nodes are up and running

```bash
make ssh/master
kubectl get nodes
```

</p></details>

**TASKS (additional)**

- Deploy metallb as a loadbalancer

<details><summary>Solution</summary>
<p>

Since this is local we use metallb to create services of type LoadBalancer on our cluster. This is not an exam item but would be required for testing out anything relating to loadbalancers in your testing. It has been almost entirely automated and only takes a minute to get deployed anyway.

```bash
make kube/clean kube/deploy/metallb
```

The kube config file will have been pulled into the ./.local/kubeconfig/ folder when we get to this point. You can use this to optionally run any kubectl commands outside of the nodes by using the following command.

```bash
export KUBECONFIG=$(pwd)/.local/kubeconfig/config
kubectl get nodes
```

</p></detail>

**TASKS (additional)**

- Deploy NFS as a persistent storage provider

<details><summary>Solution</summary>
<p>

On each node within the `/root` path will be a set of files which can be used to bootstrap an nfs server as well as deploy nfs provisioner to the cluster.

```bash
# Assuming you are on the root node and your cluster has been fully deployed already,
sudo su -
chmod +x *.sh
./install-nfs.sh
./bootstrap-nfs-provisioner.sh
```

This also sets the default storage class to nfs-storage.

</p></detail>