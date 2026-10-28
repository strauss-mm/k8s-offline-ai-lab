# Lab 03: Deployments

Learn to create, scale, update, and rollback Deployments — the primary way to run stateless applications.

## Part 1: Create a Deployment

**Imperative (quick):**
```bash
kubectl create deployment web --image=nginx:1.27 --replicas=3
```

**Declarative (write the manifest):**

Create `deployment-nginx.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
spec:
  replicas: 3
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      containers:
      - name: nginx
        image: nginx:1.27
        ports:
        - containerPort: 80
```

```bash
kubectl apply -f deployment-nginx.yaml
kubectl get deployments
kubectl get replicasets
kubectl get pods -l app=web
```

**Observe:** The Deployment creates a ReplicaSet, which creates the Pods. Three levels of objects.

## Part 2: Scale

Scale up to 5 replicas:

```bash
kubectl scale deployment web --replicas=5
kubectl get pods -l app=web
```

Scale back down:

```bash
kubectl scale deployment web --replicas=3
kubectl get pods -l app=web -w
```

Watch the extra Pods terminate.

**Question:** What happens to the ReplicaSet when you scale? (Hint: `kubectl get rs`)

## Part 3: Rolling Update

Update the nginx image. Since we're offline, we'll use the same image we already loaded, but in a real scenario you'd change the tag:

```bash
# Record the change for rollout history
kubectl set image deployment/web nginx=busybox --record
```

This triggers a rolling update. Watch it:

```bash
kubectl rollout status deployment/web
kubectl get pods -l app=web -w
```

The busybox image will cause CrashLoopBackOff (no long-running process by default) — that's intentional. You now have a broken deployment to rollback.

**Examine what happened:**

```bash
kubectl get replicasets
kubectl describe deployment web
```

Notice: the old ReplicaSet still exists (scaled to 0), and a new one was created.

## Part 4: Rollback

Roll back to the previous working version:

```bash
kubectl rollout undo deployment/web
kubectl rollout status deployment/web
kubectl get pods -l app=web
```

Verify nginx is back:

```bash
kubectl describe pod -l app=web | grep Image:
```

**View rollout history:**

```bash
kubectl rollout history deployment/web
kubectl rollout history deployment/web --revision=1
```

## Part 5: Update Strategy

Examine the default update strategy:

```bash
kubectl explain deployment.spec.strategy
kubectl get deployment web -o yaml | grep -A5 strategy
```

The default is `RollingUpdate` with `maxUnavailable: 25%` and `maxSurge: 25%`.

**Exercise:** Edit the deployment to use `maxUnavailable: 0` and `maxSurge: 1` (zero-downtime, one Pod at a time):

```bash
kubectl edit deployment web
```

Or patch it:

```bash
kubectl patch deployment web -p '{"spec":{"strategy":{"rollingUpdate":{"maxUnavailable":0,"maxSurge":1}}}}'
```

## Cleanup

```bash
kubectl delete deployment web
```

## Key Takeaways

- Deployments manage ReplicaSets, which manage Pods
- `kubectl rollout` controls update lifecycle
- Old ReplicaSets are preserved (scaled to 0) for rollback
- `--record` annotates the change cause in rollout history
- Default strategy: RollingUpdate (25% maxUnavailable, 25% maxSurge)
- `kubectl rollout undo` is your safety net

## Questions for Your AI Tutor

- "Explain the relationship between Deployments, ReplicaSets, and Pods"
- "What is the difference between maxSurge and maxUnavailable?"
- "When would I use Recreate strategy instead of RollingUpdate?"

## Solution

Manifest: [../manifests/deployment-nginx.yaml](../manifests/deployment-nginx.yaml)
