**TASKS**

- Deploy Kubernetes via kubeadm

<details><summary>Solution</summary>
<p>

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