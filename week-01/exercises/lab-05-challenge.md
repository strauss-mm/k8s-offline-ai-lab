# Lab 05: End-of-Week Challenge

Deploy a 2-tier application from scratch. No step-by-step instructions — use what you learned this week.

## The Task

Deploy a web application with:

1. **Frontend**: nginx serving as a reverse proxy (2 replicas)
2. **Backend**: Redis as a data store (1 replica)
3. Both exposed via ClusterIP Services
4. Frontend Pods must be able to reach Redis by Service name

## Requirements

- All resources in the `default` namespace
- Use proper labels on everything (`app`, `tier`)
- Frontend Deployment: 2 replicas, image `nginx:1.27`, port 80
- Redis Deployment: 1 replica, image `redis:7`, port 6379
- ClusterIP Service for each
- Frontend Service named `frontend`
- Redis Service named `redis`

## Verification

After deploying, run these checks:

```bash
# All Pods running
kubectl get pods -l tier=frontend
kubectl get pods -l tier=backend

# Services exist with correct endpoints
kubectl get svc frontend
kubectl get svc redis
kubectl get endpoints frontend
kubectl get endpoints redis

# Frontend can reach Redis
kubectl exec -it $(kubectl get pod -l tier=frontend -o jsonpath='{.items[0].metadata.name}') -- \
  sh -c "apt-get update -qq && apt-get install -qq -y redis-tools > /dev/null 2>&1 && redis-cli -h redis ping"
```

Expected output of the redis-cli command: `PONG`

If you don't want to install redis-tools, a simpler connectivity check:

```bash
kubectl run test --image=busybox --rm -it --restart=Never -- \
  sh -c "echo PING | nc redis 6379"
```

Expected: a response starting with `+PONG`

## Stretch Goals

1. Add resource requests and limits to all containers
2. Add a `version: v1` label to all resources
3. Create a NodePort Service for the frontend accessible on port 30080
4. Write all manifests in a single file separated by `---`

## Hints

<details>
<summary>Hint 1: Manifest structure</summary>

You need 4 manifests: 2 Deployments + 2 Services. The Service `selector` must match the Deployment's Pod template `labels`.

</details>

<details>
<summary>Hint 2: Redis defaults</summary>

Redis listens on port 6379 by default. No special command or args needed — the default image entrypoint works.

</details>

<details>
<summary>Hint 3: DNS</summary>

A Service named `redis` in the `default` namespace is reachable as just `redis` from any Pod in the same namespace.

</details>

---

## Solution

Only look after you've attempted the challenge yourself.

<details>
<summary>Full Solution</summary>

### Redis Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: redis
  labels:
    app: redis
    tier: backend
spec:
  replicas: 1
  selector:
    matchLabels:
      app: redis
      tier: backend
  template:
    metadata:
      labels:
        app: redis
        tier: backend
    spec:
      containers:
      - name: redis
        image: redis:7
        ports:
        - containerPort: 6379
        resources:
          requests:
            cpu: 50m
            memory: 64Mi
          limits:
            cpu: 200m
            memory: 128Mi
```

### Redis Service

```yaml
apiVersion: v1
kind: Service
metadata:
  name: redis
  labels:
    app: redis
    tier: backend
spec:
  type: ClusterIP
  selector:
    app: redis
    tier: backend
  ports:
  - port: 6379
    targetPort: 6379
```

### Frontend Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
  labels:
    app: frontend
    tier: frontend
spec:
  replicas: 2
  selector:
    matchLabels:
      app: frontend
      tier: frontend
  template:
    metadata:
      labels:
        app: frontend
        tier: frontend
    spec:
      containers:
      - name: nginx
        image: nginx:1.27
        ports:
        - containerPort: 80
        resources:
          requests:
            cpu: 50m
            memory: 64Mi
          limits:
            cpu: 200m
            memory: 128Mi
```

### Frontend Service

```yaml
apiVersion: v1
kind: Service
metadata:
  name: frontend
  labels:
    app: frontend
    tier: frontend
spec:
  type: ClusterIP
  selector:
    app: frontend
    tier: frontend
  ports:
  - port: 80
    targetPort: 80
```

</details>

## Solution Manifests

- [../manifests/challenge-redis.yaml](../manifests/challenge-redis.yaml) — Redis Deployment + Service
- [../manifests/challenge-frontend.yaml](../manifests/challenge-frontend.yaml) — Frontend Deployment + Service
