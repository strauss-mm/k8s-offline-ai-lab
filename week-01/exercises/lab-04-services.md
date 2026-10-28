# Lab 04: Services

Expose your workloads to the network. Services provide stable endpoints for Pods that come and go.

## Setup

Make sure the Deployment from Lab 03 is running:

```bash
kubectl create deployment web --image=nginx:1.27 --replicas=3
kubectl get pods -l app=web
```

## Part 1: ClusterIP Service

ClusterIP is the default — accessible only inside the cluster.

**Imperative:**
```bash
kubectl expose deployment web --port=80 --target-port=80 --type=ClusterIP --name=web-clusterip
```

**Declarative** — create `service-clusterip.yaml`:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: web-clusterip
spec:
  type: ClusterIP
  selector:
    app: web
  ports:
  - port: 80
    targetPort: 80
```

Inspect:

```bash
kubectl get svc web-clusterip
kubectl describe svc web-clusterip
kubectl get endpoints web-clusterip
```

**Observe:** The Endpoints list matches the Pod IPs. The Service watches Pods with `app: web` label.

## Part 2: Test ClusterIP Connectivity

Launch a test Pod and hit the Service:

```bash
kubectl run test --image=busybox --rm -it --restart=Never -- wget -qO- http://web-clusterip
```

You should see the nginx welcome page HTML.

**Test DNS resolution:**

```bash
kubectl run test --image=busybox --rm -it --restart=Never -- nslookup web-clusterip
```

The Service is reachable by name from any Pod in the same namespace.

**Cross-namespace format** (for future reference):

```
<service-name>.<namespace>.svc.cluster.local
```

## Part 3: NodePort Service

NodePort opens a port on every node, accessible from outside the cluster.

**Imperative:**
```bash
kubectl expose deployment web --port=80 --target-port=80 --type=NodePort --name=web-nodeport
```

**Declarative** — create `service-nodeport.yaml`:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: web-nodeport
spec:
  type: NodePort
  selector:
    app: web
  ports:
  - port: 80
    targetPort: 80
    nodePort: 30080
```

```bash
kubectl apply -f service-nodeport.yaml
kubectl get svc web-nodeport
```

**Access from the host** (kind-specific):

```bash
# Get the node's IP
kubectl get nodes -o wide

# For kind: the node IP is a Docker container IP
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
curl http://${NODE_IP}:30080
```

## Part 4: Examine the Relationship

**Scale the Deployment and watch Endpoints update:**

```bash
kubectl get endpoints web-clusterip -w &
kubectl scale deployment web --replicas=5
# Watch new endpoints appear
kubectl scale deployment web --replicas=2
# Watch endpoints disappear
fg  # Ctrl+C to stop the watch
```

**Delete a Pod and watch it recover:**

```bash
kubectl get pods -l app=web
kubectl delete pod <pick-one>
kubectl get endpoints web-clusterip
```

The Deployment creates a replacement Pod, and the Service automatically includes it.

## Part 5: Selector Deep Dive

What happens if the selector doesn't match?

```bash
# Create a Service with a wrong selector
kubectl create service clusterip orphan-svc --tcp=80:80
kubectl get endpoints orphan-svc
```

The Endpoints list is empty — no Pods have the matching label.

```bash
kubectl describe svc orphan-svc
kubectl delete svc orphan-svc
```

**Lesson:** Services find Pods by label selectors. Mismatched labels = no traffic.

## Cleanup

```bash
kubectl delete deployment web
kubectl delete svc web-clusterip web-nodeport
```

## Key Takeaways

- ClusterIP: internal only, stable DNS name
- NodePort: external access via `<NodeIP>:<NodePort>` (range 30000-32767)
- Services select Pods by labels — mismatched labels mean no endpoints
- `kubectl get endpoints` shows which Pod IPs a Service routes to
- DNS: `<svc>.<ns>.svc.cluster.local` from any Pod in the cluster
- Endpoints update automatically as Pods scale up/down or restart

## Questions for Your AI Tutor

- "What is the difference between port, targetPort, and nodePort?"
- "How does kube-proxy implement Services?"
- "When would I use LoadBalancer type?" (trick question for offline/kind)

## Solutions

Manifests: [../manifests/service-clusterip.yaml](../manifests/service-clusterip.yaml), [../manifests/service-nodeport.yaml](../manifests/service-nodeport.yaml)
