## Deploy Kubernetes (via kubeadm)

```bash
make ssh-master

# Deploy initial master
sudo kubeadm init --pod-network-cidr=10.244.0.0/16

# Configure kubectl access
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# Deploy Flannel as a network plugin
kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/2140ac876ef134e0ed5af15c65e414cf26827915/Documentation/kube-flannel.yml
```

Copy the output from the first step and deploy to the other nodes using something like this:

```bash
make ssh-worker1
sudo kubeadm join 172.16.1.11:6443 --token xqckqj.2j6umqdoe416ra9p --discovery-token-ca-cert-hash sha256:6701e97f40377b98e0ae2d35add6ada9050158ab876f9669b22ff09dedae8897
exit

make ssh-worker2
sudo kubeadm join 172.16.1.11:6443 --token xqckqj.2j6umqdoe416ra9p --discovery-token-ca-cert-hash sha256:6701e97f40377b98e0ae2d35add6ada9050158ab876f9669b22ff09dedae8897
exit
```

Then validate on the master node that all nodes are up and running

```bash
make ssh-master
kubectl get nodes
```

Then deploy metallb as a loadbalancer.

```bash
make kube/deploy/metallb
```

The kube config file will have been pulled into the ./.local/kubeconfig/ folder when we get to this point. You can use this to optionally run any kubectl commands outside of the nodes by using the following command.

```bash
export KUBECONFIG=$(pwd)/.local/kubeconfig/config
kubectl get nodes
```

From here you should be ready to do any other excercises required to study for the exam.