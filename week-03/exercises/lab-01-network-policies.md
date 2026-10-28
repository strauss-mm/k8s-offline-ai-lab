# Lab 01: Network Policies

## Objective

Implement network segmentation for a 3-tier application using Kubernetes NetworkPolicies. You'll start with default-deny and progressively allow only the traffic flows your application needs.

## Prerequisites

Your cluster must be running Calico CNI. Kind's default CNI (kindnet) does not enforce NetworkPolicies.

```bash
# Verify Calico is running
kubectl -n kube-system get pods -l k8s-app=calico-node
```

## Setup

Create a namespace and deploy the 3-tier application:

```bash
kubectl create namespace tier-app
kubectl config set-context --current --namespace=tier-app
kubectl apply -f ../manifests/frontend-deploy.yaml
kubectl apply -f ../manifests/backend-deploy.yaml
kubectl apply -f ../manifests/database-deploy.yaml
```

Verify all pods are running:

```bash
kubectl get pods -o wide
```

Note the ClusterIP of each service:

```bash
kubectl get svc
```

## Exercise 1: Verify open communication (baseline)

Before applying any policies, confirm all pods can talk to each other:

```bash
# Get pod names
FRONTEND=$(kubectl get pod -l app=frontend -o jsonpath='{.items[0].metadata.name}')
BACKEND=$(kubectl get pod -l app=backend -o jsonpath='{.items[0].metadata.name}')
DATABASE=$(kubectl get pod -l app=database -o jsonpath='{.items[0].metadata.name}')

# Frontend -> Backend (should succeed)
kubectl exec $FRONTEND -- wget -qO- --timeout=3 http://backend/

# Frontend -> Database (should succeed)
kubectl exec $FRONTEND -- wget -qO- --timeout=3 http://database/

# Backend -> Database (should succeed)
kubectl exec $BACKEND -- wget -qO- --timeout=3 http://database/
```

All three should return the nginx welcome page. This is the insecure default: every pod can reach every other pod.

## Exercise 2: Apply default deny

Create and apply a NetworkPolicy that blocks all ingress and egress traffic in the namespace.

**Write this yourself first**, then check the solution.

<details>
<summary>Hint</summary>

The policy needs:
- `podSelector: {}` to match all pods
- Both `Ingress` and `Egress` in `policyTypes`
- No ingress or egress rules (empty = deny all)

</details>

```bash
kubectl apply -f ../manifests/netpol-default-deny.yaml
```

### Verify everything is blocked

```bash
# Frontend -> Backend (should timeout)
kubectl exec $FRONTEND -- wget -qO- --timeout=3 http://backend/
# Expected: wget: download timed out

# Backend -> Database (should timeout)
kubectl exec $BACKEND -- wget -qO- --timeout=3 http://database/
# Expected: wget: download timed out
```

## Exercise 3: Allow frontend to backend

Create a NetworkPolicy that allows:
- Ingress to backend pods on port 80, only from frontend pods
- Egress from frontend pods to backend pods on port 80

**Write this yourself first.**

<details>
<summary>Hint</summary>

You need TWO policies (or one on each side):
1. Allow ingress to pods with `app: backend` from pods with `app: frontend` on port 80
2. Allow egress from pods with `app: frontend` to pods with `app: backend` on port 80

You also need to allow DNS egress (port 53 UDP) so pods can resolve service names.

</details>

```bash
kubectl apply -f ../manifests/netpol-frontend-to-backend.yaml
```

### Verify

```bash
# Frontend -> Backend (should succeed now)
kubectl exec $FRONTEND -- wget -qO- --timeout=3 http://backend/

# Frontend -> Database (should still timeout)
kubectl exec $FRONTEND -- wget -qO- --timeout=3 http://database/
# Expected: wget: download timed out
```

## Exercise 4: Allow backend to database

Create a NetworkPolicy that allows:
- Ingress to database pods on port 6379, only from backend pods
- Egress from backend pods to database pods on port 6379

```bash
kubectl apply -f ../manifests/netpol-backend-to-database.yaml
```

### Verify the complete flow

```bash
# Frontend -> Backend: ALLOWED
kubectl exec $FRONTEND -- wget -qO- --timeout=3 http://backend/

# Backend -> Database: ALLOWED
kubectl exec $BACKEND -- sh -c 'echo PING | nc -w 3 database 6379'

# Frontend -> Database: BLOCKED
kubectl exec $FRONTEND -- wget -qO- --timeout=3 http://database/
# Expected: wget: download timed out

# Database -> Frontend: BLOCKED
kubectl exec $DATABASE -- wget -qO- --timeout=3 http://frontend/
# Expected: wget: download timed out
```

## Exercise 5: Egress restriction

Create a policy that prevents the database from making any outbound connections. This is defense-in-depth: even if the database pod is compromised, it cannot exfiltrate data.

<details>
<summary>Solution</summary>

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: database-deny-egress
  namespace: tier-app
spec:
  podSelector:
    matchLabels:
      app: database
  policyTypes:
    - Egress
  # No egress rules = deny all outbound
```

</details>

## Verification checklist

| Source | Destination | Port | Expected |
|--------|------------|------|----------|
| frontend | backend | 80 | ALLOWED |
| frontend | database | 6379 | BLOCKED |
| backend | database | 6379 | ALLOWED |
| backend | frontend | 80 | BLOCKED |
| database | backend | any | BLOCKED |
| database | frontend | any | BLOCKED |

## Cleanup

```bash
kubectl delete namespace tier-app
```

## Key takeaways

- Without NetworkPolicies, all pod-to-pod traffic is allowed by default
- Default-deny is the foundation: start by blocking everything, then allow specific flows
- You need to allow DNS (port 53 UDP to kube-system) for service name resolution
- Policies are additive: if any policy allows a connection, it is allowed
- Always test both allowed and denied paths after applying policies
- Calico (or another CNI that supports NetworkPolicy) is required for enforcement
