# Lab 05: Week 2 Challenge

## Scenario

Deploy a production-ready application that combines everything from this week:
- Namespace isolation with resource constraints
- Configuration via ConfigMaps
- Credentials via Secrets
- Persistent data storage
- External access via Ingress

Write all YAML by hand before checking the solution.

---

## Requirements

1. **Namespace:** `production` with a ResourceQuota:
   - Max 4 Pods
   - Max 1 CPU (requests)
   - Max 1Gi memory (requests)

2. **ConfigMap** named `myapp-config` with:
   - `DATABASE_HOST=db.production.local`
   - `DATABASE_PORT=5432`
   - `CACHE_TTL=600`

3. **Secret** named `myapp-credentials` with:
   - `DB_USERNAME=produser`
   - `DB_PASSWORD=Pr0d$ecure!`

4. **PersistentVolume** named `myapp-pv`: 2Gi, ReadWriteOnce, hostPath `/data/myapp`

5. **PersistentVolumeClaim** named `myapp-pvc` in the `production` namespace: 1Gi

6. **Deployment** named `myapp` in `production`:
   - 2 replicas
   - Image: `nginx:1.27`
   - ConfigMap values as environment variables
   - Secret values as environment variables
   - PVC mounted at `/app/data`
   - Resource requests: 200m CPU, 128Mi memory
   - Resource limits: 400m CPU, 256Mi memory

7. **Service** named `myapp-svc`: ClusterIP, port 80

8. **Ingress**: route `/myapp` to `myapp-svc`

---

## Hints

- Create the namespace and quota first, or Pods without resources will be rejected
- PVs are cluster-scoped; PVCs are namespace-scoped
- The ConfigMap and Secret must be in the same namespace as the Deployment
- Create the hostPath directory on the kind node before applying the PV
- Remember the rewrite-target annotation on the Ingress

---

## Verification Steps

After deploying everything, verify:

```bash
# 1. Namespace and quota
kubectl describe quota -n production

# 2. ConfigMap
kubectl get configmap myapp-config -n production -o yaml

# 3. Secret
kubectl get secret myapp-credentials -n production -o yaml

# 4. PV/PVC bound
kubectl get pv myapp-pv
kubectl get pvc myapp-pvc -n production

# 5. Deployment running
kubectl get deployment myapp -n production
kubectl get pods -n production

# 6. Env vars in Pod
kubectl exec -n production deploy/myapp -- env | grep -E 'DATABASE|DB_|CACHE'

# 7. PVC mounted
kubectl exec -n production deploy/myapp -- ls /app/data

# 8. Service endpoints
kubectl get endpoints myapp-svc -n production

# 9. Ingress
curl localhost/myapp
```

---

## Solution

<details>
<summary>Complete Solution (try it yourself first)</summary>

Create the hostPath on the kind node:
```bash
docker exec kind-control-plane mkdir -p /data/myapp
```

Apply `manifests/challenge-full.yaml`:
```yaml
# Namespace
apiVersion: v1
kind: Namespace
metadata:
  name: production
  labels:
    env: production
---
# ResourceQuota
apiVersion: v1
kind: ResourceQuota
metadata:
  name: prod-quota
  namespace: production
spec:
  hard:
    pods: "4"
    requests.cpu: "1"
    requests.memory: "1Gi"
---
# ConfigMap
apiVersion: v1
kind: ConfigMap
metadata:
  name: myapp-config
  namespace: production
data:
  DATABASE_HOST: "db.production.local"
  DATABASE_PORT: "5432"
  CACHE_TTL: "600"
---
# Secret
apiVersion: v1
kind: Secret
metadata:
  name: myapp-credentials
  namespace: production
type: Opaque
stringData:
  DB_USERNAME: "produser"
  DB_PASSWORD: "Pr0d$ecure!"
---
# PersistentVolume (cluster-scoped, no namespace)
apiVersion: v1
kind: PersistentVolume
metadata:
  name: myapp-pv
spec:
  capacity:
    storage: 2Gi
  accessModes:
  - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  hostPath:
    path: /data/myapp
    type: DirectoryOrCreate
---
# PersistentVolumeClaim
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: myapp-pvc
  namespace: production
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
---
# Deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
  namespace: production
spec:
  replicas: 2
  selector:
    matchLabels:
      app: myapp
  template:
    metadata:
      labels:
        app: myapp
    spec:
      containers:
      - name: nginx
        image: nginx:1.27
        ports:
        - containerPort: 80
        envFrom:
        - configMapRef:
            name: myapp-config
        env:
        - name: DB_USERNAME
          valueFrom:
            secretKeyRef:
              name: myapp-credentials
              key: DB_USERNAME
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: myapp-credentials
              key: DB_PASSWORD
        resources:
          requests:
            cpu: 200m
            memory: 128Mi
          limits:
            cpu: 400m
            memory: 256Mi
        volumeMounts:
        - name: data
          mountPath: /app/data
      volumes:
      - name: data
        persistentVolumeClaim:
          claimName: myapp-pvc
---
# Service
apiVersion: v1
kind: Service
metadata:
  name: myapp-svc
  namespace: production
spec:
  selector:
    app: myapp
  ports:
  - port: 80
    targetPort: 80
---
# Ingress
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: myapp-ingress
  namespace: production
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  ingressClassName: nginx
  rules:
  - http:
      paths:
      - path: /myapp
        pathType: Prefix
        backend:
          service:
            name: myapp-svc
            port:
              number: 80
```

```bash
kubectl apply -f manifests/challenge-full.yaml
```

Verify everything:
```bash
kubectl get all -n production
kubectl describe quota prod-quota -n production
kubectl get pv myapp-pv
kubectl get pvc -n production
kubectl exec -n production deploy/myapp -- env | grep -E 'DATABASE|DB_|CACHE'
kubectl exec -n production deploy/myapp -- ls /app/data
curl localhost/myapp
```
</details>

---

## AI Review Exercise

Paste your solution YAML into your local LLM and ask:

> "Review this Kubernetes manifest for a production deployment. Check for: missing resource limits, security issues with Secrets, correct PV/PVC binding, Ingress configuration errors, and any best practices violations."

Compare its feedback against the solution.

## Cleanup

```bash
kubectl delete namespace production
kubectl delete pv myapp-pv
docker exec kind-control-plane rm -rf /data/myapp
kubectl config set-context --current --namespace=default
```
