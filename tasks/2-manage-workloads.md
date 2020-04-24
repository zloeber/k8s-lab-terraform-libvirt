
## Application Lifecycle Management

**TASK:** Create a deployment named nginx-deploy in the ngx namespace using nginx image version 1.16 with three replicas. Check that the deployment rolled out and show running pods.

<details><summary>Solution</summary>
<p>
```bash
# Create the template from kubectl
kubectl create ns ngx -o yaml --dry-run=true > nginx-deploy.yml
echo '---' >> nginx-deploy.yml
kubectl create deployment nginx-deploy --image=nginx:1.16 --dry-run=true -o yaml -n ngx >> nginx-deploy.yml

# Edit the template and add the namespace, and the replica number
nano nginx-deploy.yml
```

```bash
# Deploy
kubectl deploy -f ./nginx-deploy.yml

# Validate
kubectl -n ngx rollout status deployment nginx-deploy
kubectl -n ngx get deployment
kubectl -n ngx get pods
```
</p>
</details>

**TASKS:** 

- Scale the prior deployment to 5 replicas and check the status again.
- Then change prior deployment's image tag of nginx container from 1.16 to 1.17.

<details><summary>Solution</summary>
<p>

```bash
kubectl -n ngx scale deployment nginx-deploy --replicas=5
kubectl -n ngx rollout status deployment nginx-deploy
kubectl -n ngx get deploy
kubectl -n ngx get pods
```

Change the image tag:

```bash
kubectl -n ngx edit deployment/nginx-deploy
...
    spec:
      containers:
      - image: nginx:1.17
        imagePullPolicy: IfNotPresent
...
```

Check that new replicaset was created and new pods were deployed:

```bash
kubectl -n ngx get replicaset
kubectl -n ngx get pods
```
</p>
</details>

**TASKS:**
- Check the history of the deployment and rollback to previous revision.
- Then check that the nginx image was reverted to 1.16.

<details><summary>Solution</summary>
<p>

```bash
kubectl -n ngx rollout history deployment nginx-deploy
kubectl -n ngx rollout undo deployment nginx-deploy

kubectl -n ngx get replicaset
kubectl -n ngx get pods
kubectl -n ngx get pods nginx-deploy-7ff78f74b9-72xc8 -o jsonpath='{.spec.containers[0].image}'
```
</p>
</details>

## Environment variables

Doc: https://kubernetes.io/docs/tasks/inject-data-application/define-environment-variable-container/

**TASKS:**
- Create a pod with the latest busybox image running a sleep for 1 hour, and give it an environment variable named `PLANET` with the value `blue`.
- Then exec a command in the container to show that it has the configured environment variable.

<details><summary>Solution</summary>
<p>


The pod yaml `envvar.yml`:
```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  labels:
    run: envvar
  name: envvar
spec:
  containers:
  - image: busybox:latest
    name: envvar
    args:
      - sleep
      - "3600"
    env:
    - name: PLANET
      value: "blue"
EOF

# Check the env variable:
kubectl exec envvar -- env | grep PLANET
```

</p>
</details>

## ConfigMaps

Doc: https://kubernetes.io/docs/tasks/configure-pod-container/configure-pod-configmap/

**TASKS**
- Create a configmap named `space` with two values `planet=blue` and `moon=white`.
- Create a pod similar to the previous where you have two environment variables taken from the above configmap and show them in the container.

<details><summary>Solution</summary>
<p>

```bash
kubectl create configmap space --from-literal=planet=blue --from-literal=moon=white

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  labels:
    run: envvar
  name: envvar
spec:
  containers:
  - image: busybox:latest
    name: envvar
    args:
      - sleep
      - "3600"
    env:
      - name: PLANET
        valueFrom:
          configMapKeyRef:
            name: space
            key: planet
      - name: MOON
        valueFrom:
          configMapKeyRef:
            name: space
            key: moon
EOF

kubectl exec envvar -- env | grep -E "PLANET|MOON"
```

</p>
</details>


**TASKS**
- Create a configmap named `space-system` that contains a file named `system.conf` with the values `planet=blue` and `moon=white`.
- Mount the configmap to a pod and display it from the container through the path `/etc/system.conf`

<details><summary>Solution</summary>
<p>

```bash
cat << EOF > system.conf
planet=blue
moon=white
EOF

kubectl create configmap space-system --from-file=system.conf

cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  labels:
    run: confvolume
  name: confvolume
spec:
  containers:
  - image: busybox:latest
    name: confvolume
    args:
      - sleep
      - "3600"
    volumeMounts:
      - name: system
        mountPath: /etc/system.conf
        subPath: system.conf
    resources: {}
  volumes:
  - name: system
    configMap:
      name: space-system
EOF

kubectl exec confvolume -- cat /etc/system.conf
```
</p>
</details>

## Secrets

Doc: https://kubernetes.io/docs/concepts/configuration/secret/

**TASKS**
- Create a secret from files containing a username and a password.
- Use the secrets to define environment variables and display them.
- Mount the secret to a pod to `admin-cred` folder and display it.

<details><summary>Solution</summary>
<p>

Create secret.

```bash
echo -n 'admin' > username
echo -n 'admin-pass' > password

kubectl create secret generic admin-cred --from-file=username --from-file=password
```

Use secret as environment variables.

```yaml
apiVersion: v1
kind: Pod
metadata:
  labels:
    run: secretenv
  name: secretenv
spec:
  containers:
  - image: busybox:latest
    name: secretenv
    args:
      - sleep
      - "3600"
    env:
      - name: USERNAME
        valueFrom:
          secretKeyRef:
            name: admin-cred
            key: username
      - name: PASSWORD
        valueFrom:
          secretKeyRef:
            name: admin-cred
            key: password

```

```bash
kubectl apply -f secretenv.yml

kubectl exec secretenv -- env | grep -E "USERNAME|PASSWORD"
USERNAME=admin
PASSWORD=admin-pass
```

Mount a secret to pod:

```yaml
apiVersion: v1
kind: Pod
metadata:
  labels:
    run: secretvolume
  name: secretvolume
spec:
  containers:
  - image: busybox:latest
    name: secretvolume
    args:
      - sleep
      - "3600"
    volumeMounts:
      - name: admincred
        mountPath: /etc/admin-cred
        readOnly: true
  volumes:
  - name: admincred
    secret:
      secretName: admin-cred

```

```bash
kubectl apply -f secretvolume.yml

kubectl exec secretvolume -- ls /etc/admin-cred
password
username

kubectl exec secretvolume -- cat /etc/admin-cred/username
admin

kubectl exec secretvolume -- cat /etc/admin-cred/password
admin-pass
```

</p>
</details>


## Know how to scale applications

Docs:
- https://kubernetes.io/docs/concepts/workloads/controllers/deployment/
- https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/

**TASKS**

- Create a deployment with the latest nginx image and scale the deployment to 4 replicas.

<details><summary>Solution</summary>
<p>

```bash
kubectl create deployment scalable --image=nginx:latest
kubectl scale deployment scalable --replicas=4
kubectl get pods
```
</p>
</details>

**TASKS**

- Autoscale a deployment to have a minimum of two pods and a maximum of 6 pods and that transitions when cpu usage goes above 70%.

<details><summary>Solution</summary>
<p>

In order to use Horizontal Pod Autoscaling, you need to have the metrics server installed in you cluster.

```bash
# Install metrics server
git clone https://github.com/kubernetes-sigs/metrics-server
kubectl apply -f metrics-server/deploy/kubernetes/

# Autoscale a deployment
kubectl create deployment autoscalable --image=nginx:latest
kubectl autoscale deployment autoscalable --min=2 --max=6 --cpu-percent=70
kubectl get hpa
kubectl get pods
```
</p>
</details>
