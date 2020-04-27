# Backup and Restore Tasks

Quick note on using etcdctl from a kubeadm deployed cluster:

```bash
# Install etcdctl
sudo apt install etcd-client

# Save a snapshot:
sudo su -

ETCDCTL_API=3 etcdctl --endpoints https://127.0.0.1:2379 --cacert=/etc/kubernetes/pki/etcd/ca.crt --cert=/etc/kubernetes/pki/etcd/healthcheck-client.crt --key /etc/kubernetes/pki/etcd/healthcheck-client.key snapshot save ./snapshot.db
```