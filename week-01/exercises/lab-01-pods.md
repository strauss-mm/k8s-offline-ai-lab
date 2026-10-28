# Lab 01: Pods and kubectl Basics

Learn to create, inspect, and interact with Pods — the smallest deployable unit in Kubernetes.

## Part 1: Create a Pod

Create a simple nginx Pod using the imperative command:

```bash
kubectl run web --image=nginx:1.27
```

Now inspect it:

```bash
kubectl get pods
kubectl get pods -o wide
kubectl describe pod web
kubectl logs web
```

**Questions to answer:**
1. What node is the Pod running on?
2. What IP address was assigned?
3. What is the Pod's restart policy?

## Part 2: Create a Pod from a Manifest

Write a Pod manifest by hand. Start with the scaffold:

```bash
kubectl run web2 --image=nginx:1.27 --dry-run=client -o yaml
```

Study the output. Now write `pod-basic.yaml` from scratch (don't copy-paste — typing builds muscle memory):

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: web2
  labels:
    app: web
spec:
  containers:
  - name: nginx
    image: nginx:1.27
    ports:
    - containerPort: 80
```

Apply and verify:

```bash
kubectl apply -f pod-basic.yaml
kubectl get pods
kubectl describe pod web2
```

## Part 3: Interact with the Pod

Exec into the running container:

```bash
kubectl exec -it web2 -- /bin/sh
```

Inside the container:

```bash
hostname
cat /etc/nginx/nginx.conf
curl localhost
exit
```

View logs:

```bash
kubectl logs web2
kubectl logs web2 --follow    # stream logs (Ctrl+C to stop)
```

## Part 4: Multi-Container Pod

Create a Pod with two containers: nginx serving content and a busybox sidecar that writes to a shared volume.

Write `pod-multi-container.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: multi
  labels:
    app: multi
spec:
  containers:
  - name: nginx
    image: nginx:1.27
    ports:
    - containerPort: 80
    volumeMounts:
    - name: shared
      mountPath: /usr/share/nginx/html
  - name: sidecar
    image: busybox
    command: ["/bin/sh", "-c"]
    args:
    - while true; do echo "$(date) - sidecar writing" > /html/index.html; sleep 5; done
    volumeMounts:
    - name: shared
      mountPath: /html
  volumes:
  - name: shared
    emptyDir: {}
```

Apply and test:

```bash
kubectl apply -f pod-multi-container.yaml
kubectl get pods

# View logs from each container
kubectl logs multi -c nginx
kubectl logs multi -c sidecar

# Verify the sidecar is writing content nginx serves
kubectl exec multi -c nginx -- cat /usr/share/nginx/html/index.html
```

## Part 5: Explore with kubectl explain

Use the built-in docs to answer these questions without any web access:

```bash
kubectl explain pod.spec.restartPolicy
kubectl explain pod.spec.containers.resources
kubectl explain pod.spec.volumes
```

**Questions:**
1. What are the valid values for `restartPolicy`?
2. What fields are under `resources.limits`?
3. What volume types are available?

## Cleanup

```bash
kubectl delete pod web web2 multi
```

## Solutions

Solution manifests: [../manifests/pod-basic.yaml](../manifests/pod-basic.yaml), [../manifests/pod-multi-container.yaml](../manifests/pod-multi-container.yaml)

### Answers

**Part 1:**
1. Check the NODE column in `kubectl get pods -o wide`
2. Check the IP column in `kubectl get pods -o wide`
3. `Always` — visible in `kubectl describe pod web` under Restart Policy

**Part 5:**
1. `Always`, `OnFailure`, `Never`
2. `cpu` and `memory` (also `hugepages-*` and `ephemeral-storage`)
3. Many — including `emptyDir`, `hostPath`, `configMap`, `secret`, `persistentVolumeClaim`
