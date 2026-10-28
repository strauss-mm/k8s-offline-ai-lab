# Lab 01: Operations — Probes, PDB, and Node Drain

## Objective

Learn how Kubernetes detects unhealthy containers, protects application availability during disruptions, and safely removes workloads from nodes.

---

## Part 1: Liveness and Readiness Probes

### Concepts

- **Liveness probe**: Detects when a container is stuck. Kubernetes restarts the container when the probe fails.
- **Readiness probe**: Detects when a container is not ready to serve traffic. Kubernetes removes the Pod from Service endpoints until the probe passes.
- **Startup probe**: Gives slow-starting containers time to initialize before liveness checks begin.

### Exercise 1A: HTTP Probe

Create a Deployment with an nginx container that uses HTTP probes.

```bash
# Write the manifest yourself first, then check manifests/probes-deployment.yaml
kubectl apply -f manifests/probes-deployment.yaml
```

What to include:
- `livenessProbe` with `httpGet` on path `/` port `80`
- `readinessProbe` with `httpGet` on path `/` port `80`
- `initialDelaySeconds: 5`
- `periodSeconds: 10`
- `failureThreshold: 3`

Verify the probes are configured:

```bash
kubectl describe deployment probed-nginx
kubectl get pods -o wide
```

Look for the `Liveness` and `Readiness` lines in the Pod description. Both should show `http-get http://:80/ delay=5s timeout=1s period=10s #success=1 #failure=3`.

### Exercise 1B: Exec Probe

Create a Pod that uses an exec-based liveness probe:

```bash
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: exec-probe-test
spec:
  containers:
  - name: app
    image: busybox
    command: ["sh", "-c", "touch /tmp/healthy && sleep 3600"]
    livenessProbe:
      exec:
        command: ["cat", "/tmp/healthy"]
      initialDelaySeconds: 5
      periodSeconds: 5
EOF
```

Verify it stays running:

```bash
kubectl get pod exec-probe-test -w
```

Now delete the health file and watch Kubernetes restart the container:

```bash
kubectl exec exec-probe-test -- rm /tmp/healthy
kubectl get pod exec-probe-test -w
```

Within 5-15 seconds, the liveness probe fails and the container restarts. Check the restart count:

```bash
kubectl describe pod exec-probe-test | grep -A5 "State:"
```

### Exercise 1C: Failing Liveness Probe

Deploy a Pod that intentionally fails its liveness probe from the start:

```bash
kubectl apply -f manifests/probes-failing.yaml
kubectl get pod failing-probe -w
```

Watch the restart count climb. After `failureThreshold` consecutive failures (3 by default), Kubernetes kills and restarts the container. The Pod enters `CrashLoopBackOff` after repeated restarts.

```bash
kubectl describe pod failing-probe | grep -A3 "Liveness"
kubectl describe pod failing-probe | grep "Restart Count"
```

Clean up:

```bash
kubectl delete pod failing-probe exec-probe-test
kubectl delete deployment probed-nginx
```

---

## Part 2: PodDisruptionBudget

### Concept

A PodDisruptionBudget (PDB) limits how many Pods from a set can be voluntarily disrupted at the same time. This protects availability during node drains, cluster upgrades, and autoscaler scale-downs.

PDBs only affect **voluntary** disruptions (drain, eviction). They do not prevent involuntary disruptions like node crashes or OOM kills.

### Exercise 2A: Create a PDB

First, create a Deployment with 3 replicas:

```bash
kubectl apply -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: pdb-test
spec:
  replicas: 3
  selector:
    matchLabels:
      app: pdb-test
  template:
    metadata:
      labels:
        app: pdb-test
    spec:
      containers:
      - name: nginx
        image: nginx:1.27
EOF
```

Wait for all replicas:

```bash
kubectl rollout status deployment pdb-test
```

Now create a PDB:

```bash
kubectl apply -f manifests/pdb.yaml
```

Inspect it:

```bash
kubectl get pdb pdb-test-budget
kubectl describe pdb pdb-test-budget
```

The output shows `Allowed disruptions`. With `minAvailable: 2` and 3 replicas, 1 disruption is allowed at a time.

---

## Part 3: Node Drain

### Concept

`kubectl drain` safely evicts all Pods from a node, respecting PDBs. This is used before maintenance, upgrades, or decommissioning a node.

### Exercise 3A: Drain a Worker Node

List your nodes:

```bash
kubectl get nodes
```

In a kind cluster with the default config, you have one control-plane node. If you created a multi-node cluster (see setup), pick a worker node.

For a single-node cluster, you can still practice the commands but the drain will evict system Pods:

```bash
# Cordon prevents new Pods from being scheduled on the node
kubectl cordon <node-name>
kubectl get nodes   # Status shows SchedulingDisabled

# Drain evicts existing Pods (--ignore-daemonsets is needed for system DaemonSets)
kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data

# Watch where Pods land
kubectl get pods -o wide

# When done, uncordon to allow scheduling again
kubectl uncordon <node-name>
kubectl get nodes   # Status returns to Ready
```

If you have a PDB and not enough nodes to reschedule, the drain blocks until it can evict Pods without violating the PDB. This is the protection in action.

---

## Part 4: HorizontalPodAutoscaler (Concepts Only)

HPA automatically scales the number of Pod replicas based on CPU/memory utilization or custom metrics.

In offline mode, HPA requires the metrics-server image which you may not have pre-pulled. The concept is straightforward:

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: my-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: my-app
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 50
```

Key points:
- HPA checks metrics every 15 seconds by default
- Scale-up is immediate; scale-down has a 5-minute stabilization window
- Requires `resources.requests` set on containers
- Works with both Deployments and StatefulSets

To test HPA with metrics-server, pre-pull the image while online:
```bash
docker pull registry.k8s.io/metrics-server/metrics-server:v0.7.1
kind load docker-image registry.k8s.io/metrics-server/metrics-server:v0.7.1
```

---

## Cleanup

```bash
kubectl delete deployment pdb-test
kubectl delete pdb pdb-test-budget
```

## AI Exercises

Ask your local LLM:
- "Explain the difference between liveness and readiness probes with a real-world analogy"
- "What happens if I set initialDelaySeconds too low for a slow-starting Java application?"
- "Generate a Pod manifest with a TCP socket liveness probe on port 8080"
- "What is the difference between minAvailable and maxUnavailable in a PDB?"

Verify every answer against `kubectl explain`.
