# Lab 05: Capstone — Secured 3-Tier Application

## Objective

Deploy a fully secured 3-tier application that demonstrates everything learned in Weeks 1-4. Build it yourself first, then compare with the solution in `manifests/capstone/`.

---

## Architecture

```
              Ingress
                |
       /web     |     /api
        |       |       |
   +--------+  |  +--------+
   | Web    |  |  | API    |
   | (nginx)|  |  | (nginx)|
   | 2 reps |  |  | 2 reps |
   +--------+  |  +--------+
                |       |
                |  +--------+
                |  | Redis  |
                |  | 1 rep  |
                |  +--------+
```

**Traffic flow**: External -> Ingress -> Web/API, API -> Redis. No other internal traffic allowed.

---

## Requirements Checklist

Build your manifests to satisfy every requirement. Check each box as you complete it.

### Namespace and Policy
- [ ] All resources in namespace `production`
- [ ] PSS restricted profile enforced on namespace
- [ ] Default-deny NetworkPolicy (ingress and egress)
- [ ] Explicit NetworkPolicies: web<-ingress, api<-ingress, api->redis, all->DNS

### Workloads
- [ ] Web tier: nginx Deployment, 2 replicas, label `tier: web`
- [ ] API tier: nginx Deployment, 2 replicas, label `tier: api`
- [ ] Redis tier: redis Deployment, 1 replica, label `tier: data`
- [ ] All Deployments use ConfigMaps for configuration

### Networking
- [ ] ClusterIP Service for each tier
- [ ] Ingress: `/web` routes to web Service, `/api` routes to API Service
- [ ] Install ingress-nginx controller (pre-pull image while online)

### Security
- [ ] Dedicated ServiceAccount `app-sa` with `automountServiceAccountToken: false`
- [ ] All Pods: `runAsNonRoot: true`, `readOnlyRootFilesystem: true`
- [ ] All Pods: `allowPrivilegeEscalation: false`, `drop: ["ALL"]`
- [ ] All Pods: `runAsUser` set to image-appropriate non-root UID
- [ ] RBAC: app-sa can only get/list Pods in production namespace

### Reliability
- [ ] Liveness and readiness probes on all Deployments
- [ ] PodDisruptionBudget on web tier (minAvailable: 1)
- [ ] PodDisruptionBudget on API tier (minAvailable: 1)

### Storage
- [ ] PersistentVolume (1Gi, hostPath for kind) for Redis
- [ ] PersistentVolumeClaim bound to the PV
- [ ] Redis mounts the PVC at `/data`

---

## Step-by-Step Build Order

### Step 1: Namespace

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: production
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/warn: restricted
    pod-security.kubernetes.io/audit: restricted
```

### Step 2: RBAC

Create:
- ServiceAccount `app-sa` in `production` with `automountServiceAccountToken: false`
- Role `pod-reader` with verbs get, list on pods
- RoleBinding `app-sa-binding`

### Step 3: ConfigMaps

Create ConfigMaps for nginx configs:
- `web-config`: nginx config serving static content on port 8080 (non-privileged port)
- `api-config`: nginx config proxying to Redis or serving on port 8080

### Step 4: Storage

Create:
- PersistentVolume `redis-pv` (1Gi, hostPath `/mnt/data/redis`)
- PersistentVolumeClaim `redis-pvc` requesting 1Gi

### Step 5: Deployments

For each tier, include:
- ServiceAccount reference
- Security context (Pod-level and container-level)
- Resource requests
- Probes
- ConfigMap volume mounts
- Writable directories via emptyDir (for nginx: `/var/cache/nginx`, `/var/run`, `/tmp`)

nginx non-root notes:
- nginx official image supports non-root with UID 101
- Must listen on port 8080 (not 80, which requires root)
- Needs writable: `/var/cache/nginx`, `/var/run`, `/tmp`

Redis non-root notes:
- Redis official image runs as UID 999
- Mount PVC at `/data`
- Needs writable `/data` (the PVC itself) and `/tmp`

### Step 6: Services

ClusterIP Services for each tier, targeting port 8080 for nginx and 6379 for Redis.

### Step 7: Ingress

Requires ingress-nginx. Pre-pull while online:
```bash
docker pull registry.k8s.io/ingress-nginx/controller:v1.11.2
kind load docker-image registry.k8s.io/ingress-nginx/controller:v1.11.2
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
```

If you do not have the ingress controller images, skip this step and test Services directly with `kubectl port-forward`.

### Step 8: NetworkPolicies

Create in order:
1. Default deny all ingress and egress
2. Allow DNS egress for all Pods
3. Allow ingress to web from ingress controller
4. Allow ingress to API from ingress controller
5. Allow egress from API to Redis
6. Allow ingress to Redis from API only

### Step 9: PodDisruptionBudgets

Create PDBs for web and API tiers with `minAvailable: 1`.

---

## Validation

Run these checks after deploying everything:

### All Pods Running

```bash
kubectl -n production get pods
# All should be Running, 0 restarts
```

### Probes Working

```bash
# Kill a web container and watch it restart
kubectl -n production exec deploy/web -- kill 1
kubectl -n production get pods -w
# Container restarts, Pod stays Running
```

### PSS Enforcement

```bash
# Try to deploy a privileged Pod — should be rejected
kubectl -n production run evil --image=busybox --overrides='
{"spec":{"containers":[{"name":"evil","image":"busybox","command":["sleep","10"],
"securityContext":{"privileged":true}}]}}' 2>&1
# Expected: Forbidden
```

### NetworkPolicy Enforcement

(Requires Calico CNI)

```bash
# Web should NOT be able to reach Redis directly
WEB_POD=$(kubectl -n production get pod -l tier=web -o jsonpath='{.items[0].metadata.name}')
REDIS_IP=$(kubectl -n production get svc redis -o jsonpath='{.spec.clusterIP}')
kubectl -n production exec $WEB_POD -- wget -q --timeout=3 -O - http://$REDIS_IP:6379 2>&1
# Expected: timeout (blocked by NetworkPolicy)

# API should be able to reach Redis
API_POD=$(kubectl -n production get pod -l tier=api -o jsonpath='{.items[0].metadata.name}')
kubectl -n production exec $API_POD -- sh -c "echo PING | nc -w 2 $REDIS_IP 6379"
# Expected: +PONG
```

### Data Persistence

```bash
# Write data to Redis
API_POD=$(kubectl -n production get pod -l tier=api -o jsonpath='{.items[0].metadata.name}')
REDIS_IP=$(kubectl -n production get svc redis -o jsonpath='{.spec.clusterIP}')
kubectl -n production exec $API_POD -- sh -c "echo 'SET testkey hello' | nc -w 2 $REDIS_IP 6379"

# Delete the Redis Pod
kubectl -n production delete pod -l tier=data

# Wait for replacement
kubectl -n production wait --for=condition=Ready pod -l tier=data --timeout=60s

# Read data back
REDIS_IP=$(kubectl -n production get svc redis -o jsonpath='{.spec.clusterIP}')
kubectl -n production exec $API_POD -- sh -c "echo 'GET testkey' | nc -w 2 $REDIS_IP 6379"
# Expected: hello
```

### PDB Protection

```bash
kubectl -n production get pdb
# ALLOWED DISRUPTIONS should be 1 for each (2 replicas, minAvailable 1)
```

---

## Grading Rubric

| Criterion | Points | How to Check |
|-----------|--------|-------------|
| All Pods running, 0 restarts | 10 | `kubectl -n production get pods` |
| PSS restricted enforced | 10 | Privileged Pod rejected |
| NetworkPolicies block unauthorized traffic | 15 | Web cannot reach Redis |
| NetworkPolicies allow authorized traffic | 10 | API can reach Redis |
| RBAC: app-sa has minimal permissions | 10 | `kubectl auth can-i` checks |
| No token auto-mounted | 5 | No `/var/run/secrets` in Pods |
| All containers non-root | 10 | `id` returns non-root UID |
| Read-only filesystem with emptyDir writable dirs | 10 | `touch /etc/test` fails |
| Probes restart unhealthy containers | 10 | Kill process, watch restart |
| Redis data survives Pod deletion | 10 | Write, delete, read back |
| **Total** | **100** | |

**90-100**: Production-ready. You understand Kubernetes security deeply.
**70-89**: Solid. Review the gaps and redo those sections.
**Below 70**: Repeat Week 3 and Week 4 labs before attempting again.

---

## Solution

All solution manifests are in `manifests/capstone/`. Apply the entire solution:

```bash
kubectl apply -f manifests/capstone/
```

Apply order matters for some resources. If applying all at once fails, apply in this order:
1. `namespace.yaml`
2. `rbac.yaml`, `configmaps.yaml`
3. `redis-pv.yaml`, `redis-pvc.yaml`
4. `web-deploy.yaml`, `api-deploy.yaml`, `redis-deploy.yaml`
5. `web-service.yaml`, `api-service.yaml`, `redis-service.yaml`
6. `netpol-default-deny.yaml`, `netpol-web-to-api.yaml`, `netpol-api-to-redis.yaml`
7. `pdb-web.yaml`, `pdb-api.yaml`
8. `ingress.yaml` (only if ingress-nginx is installed)

---

## Cleanup

```bash
kubectl delete namespace production
kubectl delete pv redis-pv 2>/dev/null
```

## AI Exercises

Ask your local LLM:
- "Review this capstone architecture and suggest improvements for production readiness"
- "What additional security controls would you add for a PCI-DSS compliant cluster?"
- "Generate a trivy config scan command to audit all my YAML manifests for misconfigurations"
- "Compare this setup to the CIS Kubernetes Benchmark — what gaps remain?"
