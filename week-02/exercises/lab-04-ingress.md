# Lab 04: Ingress

## Objective

Install ingress-nginx from pre-pulled images, deploy two backend applications, and route traffic by path using an Ingress resource.

## Prerequisites

Pre-pull images while online:
```bash
docker pull registry.k8s.io/ingress-nginx/controller:v1.11.3
docker pull registry.k8s.io/ingress-nginx/kube-webhook-certgen:v1.4.4
kind load docker-image registry.k8s.io/ingress-nginx/controller:v1.11.3
kind load docker-image registry.k8s.io/ingress-nginx/kube-webhook-certgen:v1.4.4
```

## Setup

```bash
kubectl create namespace week2-lab04
kubectl config set-context --current --namespace=week2-lab04
```

---

## Exercise 1: Install ingress-nginx

Install the ingress-nginx controller using the kind-specific manifest. This manifest is pre-configured for kind's Docker networking.

<details>
<summary>Solution</summary>

While online, download the manifest for offline use:
```bash
curl -Lo manifests/ingress-nginx-deploy.yaml \
  https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.11.3/deploy/static/provider/kind/deploy.yaml
```

Apply it (works offline once downloaded):
```bash
kubectl apply -f manifests/ingress-nginx-deploy.yaml
```

Wait for the controller to be ready:
```bash
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=120s
```

Verify:
```bash
kubectl get pods -n ingress-nginx
kubectl get svc -n ingress-nginx
```

The controller Pod should be Running and the Service should exist.
</details>

---

## Exercise 2: Deploy Two Backend Apps

Deploy two nginx-based apps with different content:
- `app-a` returns "Hello from App A"
- `app-b` returns "Hello from App B"

Expose each with a ClusterIP Service on port 80.

<details>
<summary>Solution</summary>

App A — uses default nginx with a ConfigMap to customize the response:
```bash
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-a-config
data:
  index.html: |
    Hello from App A
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-a
spec:
  replicas: 1
  selector:
    matchLabels:
      app: app-a
  template:
    metadata:
      labels:
        app: app-a
    spec:
      containers:
      - name: nginx
        image: nginx:1.27
        ports:
        - containerPort: 80
        volumeMounts:
        - name: html
          mountPath: /usr/share/nginx/html
      volumes:
      - name: html
        configMap:
          name: app-a-config
---
apiVersion: v1
kind: Service
metadata:
  name: app-a-svc
spec:
  selector:
    app: app-a
  ports:
  - port: 80
    targetPort: 80
EOF
```

App B:
```bash
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-b-config
data:
  index.html: |
    Hello from App B
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-b
spec:
  replicas: 1
  selector:
    matchLabels:
      app: app-b
  template:
    metadata:
      labels:
        app: app-b
    spec:
      containers:
      - name: nginx
        image: nginx:1.27
        ports:
        - containerPort: 80
        volumeMounts:
        - name: html
          mountPath: /usr/share/nginx/html
      volumes:
      - name: html
        configMap:
          name: app-b-config
---
apiVersion: v1
kind: Service
metadata:
  name: app-b-svc
spec:
  selector:
    app: app-b
  ports:
  - port: 80
    targetPort: 80
EOF
```

Verify both are running:
```bash
kubectl get deployments
kubectl get svc
```
</details>

---

## Exercise 3: Create an Ingress Resource

Create an Ingress that routes:
- `/app-a` to `app-a-svc`
- `/app-b` to `app-b-svc`

<details>
<summary>Solution</summary>

Apply `manifests/ingress-routes.yaml`:
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: app-ingress
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  ingressClassName: nginx
  rules:
  - http:
      paths:
      - path: /app-a
        pathType: Prefix
        backend:
          service:
            name: app-a-svc
            port:
              number: 80
      - path: /app-b
        pathType: Prefix
        backend:
          service:
            name: app-b-svc
            port:
              number: 80
```

```bash
kubectl apply -f manifests/ingress-routes.yaml
kubectl get ingress
kubectl describe ingress app-ingress
```

Key fields:
- `ingressClassName: nginx` — tells K8s which Ingress controller handles this
- `rewrite-target: /` — strips the path prefix before forwarding (so `/app-a` becomes `/`)
- `pathType: Prefix` — matches the path and all subpaths
</details>

---

## Exercise 4: Test the Routes

Test from inside the cluster using a busybox Pod.

<details>
<summary>Solution</summary>

On kind, the ingress controller binds to the host network, so you can curl localhost:

```bash
# From your Kali host (kind maps ports)
curl localhost/app-a
curl localhost/app-b
```

If that doesn't work (depends on your kind config), test from inside the cluster:
```bash
# Get the ingress controller's ClusterIP
INGRESS_IP=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.spec.clusterIP}')

# Curl from a temporary Pod
kubectl run curl-test --image=busybox --restart=Never --rm -it -- \
  wget -qO- http://${INGRESS_IP}/app-a

kubectl run curl-test2 --image=busybox --restart=Never --rm -it -- \
  wget -qO- http://${INGRESS_IP}/app-b
```

Expected output:
```
Hello from App A
```
```
Hello from App B
```
</details>

---

## Exercise 5: Debugging Ingress Issues

Common problems and how to diagnose them:

<details>
<summary>Troubleshooting Guide</summary>

**1. Ingress shows no ADDRESS:**
```bash
kubectl get ingress
# If ADDRESS is blank, the controller hasn't processed it
kubectl describe ingress app-ingress
# Look for events — warnings indicate issues
kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller --tail=50
```

**2. 404 on the path:**
```bash
# Verify the backend Service exists and has endpoints
kubectl get endpoints app-a-svc
# If endpoints are empty, the selector doesn't match any Pods
kubectl get pods --show-labels
```

**3. 503 Service Unavailable:**
```bash
# The Service exists but no healthy backends
kubectl get pods
# Check if Pods are Running
kubectl describe pod <pod-name>
```

**4. Wrong content returned:**
```bash
# Check the rewrite-target annotation
# Without it, nginx forwards /app-a to the backend as /app-a
# The backend nginx looks for /app-a/index.html which doesn't exist
```
</details>

---

## Verification Checklist

- [ ] Installed ingress-nginx controller from pre-pulled images
- [ ] Deployed two apps with different content
- [ ] Created an Ingress with path-based routing
- [ ] Tested both routes and got correct responses
- [ ] Understand the rewrite-target annotation

## Cleanup

```bash
kubectl delete namespace week2-lab04
kubectl config set-context --current --namespace=default
```
