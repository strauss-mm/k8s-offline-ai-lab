# Lab 03: Namespaces, ResourceQuotas, and LimitRanges

## Objective

Isolate workloads with Namespaces, enforce resource limits with ResourceQuotas, and set per-container defaults with LimitRanges.

---

## Exercise 1: Create Namespaces

Create two namespaces: `dev` and `staging`. List all namespaces and identify the system ones.

<details>
<summary>Solution</summary>

```bash
kubectl create namespace dev
kubectl create namespace staging
kubectl get namespaces
```

System namespaces:
- `default` — where resources go if no namespace is specified
- `kube-system` — control plane components (etcd, API server, scheduler, etc.)
- `kube-public` — readable by all users, even unauthenticated (rarely used)
- `kube-node-lease` — node heartbeat leases for node health detection

Apply `manifests/namespace-dev.yaml`:
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: dev
  labels:
    env: development
```
</details>

---

## Exercise 2: Set a ResourceQuota

Apply a ResourceQuota on the `dev` namespace:
- Max 2 Pods
- Max 500m CPU (requests)
- Max 512Mi memory (requests)
- Max 1 CPU (limits)
- Max 1Gi memory (limits)

<details>
<summary>Solution</summary>

Apply `manifests/resourcequota.yaml`:
```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: dev-quota
  namespace: dev
spec:
  hard:
    pods: "2"
    requests.cpu: "500m"
    requests.memory: "512Mi"
    limits.cpu: "1"
    limits.memory: "1Gi"
```

```bash
kubectl apply -f manifests/resourcequota.yaml
kubectl describe quota dev-quota -n dev
```

You'll see `Used` vs `Hard` for each resource.
</details>

---

## Exercise 3: Deploy Pods with Resource Requests

Deploy a Pod in the `dev` namespace with explicit resource requests and limits.

<details>
<summary>Solution</summary>

```bash
kubectl run app1 -n dev --image=nginx:1.27 \
  --dry-run=client -o yaml | \
  kubectl patch -f - --local --type=json \
  -p '[{"op":"add","path":"/spec/containers/0/resources","value":{"requests":{"cpu":"200m","memory":"128Mi"},"limits":{"cpu":"400m","memory":"256Mi"}}}]' \
  --dry-run=client -o yaml | kubectl apply -f -
```

Or use a manifest:
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: app1
  namespace: dev
spec:
  containers:
  - name: nginx
    image: nginx:1.27
    resources:
      requests:
        cpu: 200m
        memory: 128Mi
      limits:
        cpu: 400m
        memory: 256Mi
```

```bash
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: app1
  namespace: dev
spec:
  containers:
  - name: nginx
    image: nginx:1.27
    resources:
      requests:
        cpu: 200m
        memory: 128Mi
      limits:
        cpu: 400m
        memory: 256Mi
EOF
```

Check quota usage:
```bash
kubectl describe quota dev-quota -n dev
```

You'll see cpu and memory usage increase.
</details>

---

## Exercise 4: Hit the Quota Limit

Deploy a second Pod that fits. Then try a third Pod — it should be rejected.

<details>
<summary>Solution</summary>

Second Pod (fits within quota):
```bash
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: app2
  namespace: dev
spec:
  containers:
  - name: nginx
    image: nginx:1.27
    resources:
      requests:
        cpu: 200m
        memory: 128Mi
      limits:
        cpu: 400m
        memory: 256Mi
EOF
```

Third Pod — rejected:
```bash
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: app3
  namespace: dev
spec:
  containers:
  - name: nginx
    image: nginx:1.27
    resources:
      requests:
        cpu: 200m
        memory: 128Mi
      limits:
        cpu: 400m
        memory: 256Mi
EOF
```

Error: `forbidden: exceeded quota: dev-quota, requested: pods=1, used: pods=2, limited: pods=2`

Also try exceeding CPU:
```bash
kubectl delete pod app2 -n dev
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: cpu-hog
  namespace: dev
spec:
  containers:
  - name: nginx
    image: nginx:1.27
    resources:
      requests:
        cpu: 400m
        memory: 128Mi
      limits:
        cpu: 800m
        memory: 256Mi
EOF
```

This exceeds the total CPU requests quota (200m used + 400m requested = 600m > 500m limit).
</details>

---

## Exercise 5: What Happens Without Resource Requests?

With a ResourceQuota active, try creating a Pod without specifying resources.

<details>
<summary>Solution</summary>

```bash
kubectl run bare-pod -n dev --image=busybox --command -- sleep 3600
```

Error: `must specify requests.cpu, requests.memory` (or similar).

When a ResourceQuota with compute constraints exists, every Pod in that namespace MUST specify resource requests and limits. Otherwise the API server can't account for the resources.

This is where LimitRanges help — they provide defaults.
</details>

---

## Exercise 6: LimitRange for Defaults

Create a LimitRange in `dev` that sets default requests and limits for containers that don't specify them.

<details>
<summary>Solution</summary>

Apply `manifests/limitrange.yaml`:
```yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: dev-limits
  namespace: dev
spec:
  limits:
  - type: Container
    default:
      cpu: 200m
      memory: 128Mi
    defaultRequest:
      cpu: 100m
      memory: 64Mi
    max:
      cpu: 500m
      memory: 512Mi
    min:
      cpu: 50m
      memory: 32Mi
```

```bash
kubectl apply -f manifests/limitrange.yaml
kubectl describe limitrange dev-limits -n dev
```

Now retry creating a Pod without resources:
```bash
kubectl delete pod app1 app2 -n dev 2>/dev/null
kubectl run auto-limits -n dev --image=busybox --command -- sleep 3600
kubectl get pod auto-limits -n dev -o jsonpath='{.spec.containers[0].resources}' | python3 -m json.tool
```

The LimitRange automatically injects the default requests and limits.

Fields:
- `default` — applied as limits if container doesn't specify
- `defaultRequest` — applied as requests if container doesn't specify
- `max` — upper bound; Pods exceeding this are rejected
- `min` — lower bound; Pods below this are rejected
</details>

---

## Verification Checklist

- [ ] Created namespaces `dev` and `staging`
- [ ] Applied a ResourceQuota to `dev`
- [ ] Deployed Pods with explicit resource requests
- [ ] Hit the Pod count quota limit
- [ ] Hit the CPU requests quota limit
- [ ] Observed that Pods without resources are rejected when a quota exists
- [ ] Applied a LimitRange to inject defaults
- [ ] Verified LimitRange defaults are applied to Pods

## Cleanup

```bash
kubectl delete namespace dev staging
kubectl config set-context --current --namespace=default
```
