# Lab 02: Broken Pods

Five broken Pod manifests. Your job: apply each one, observe the failure, diagnose it, and fix it.

**Workflow for each:**
1. Apply the manifest: `kubectl apply -f broken-pod-N.yaml`
2. Check status: `kubectl get pods`
3. Investigate: `kubectl describe pod <name>` and `kubectl logs <name>`
4. Identify the problem
5. Fix the YAML and re-apply

The broken manifests are in `../manifests/broken-pod-1.yaml` through `broken-pod-5.yaml`.

---

## Pod 1: The Typo

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: broken-1
spec:
  containers:
  - name: web
    image: ngnix:1.27
    ports:
    - containerPort: 80
```

**Apply it:**
```bash
kubectl apply -f ../manifests/broken-pod-1.yaml
kubectl get pods
```

**What you'll see:** Status `ErrImagePull` or `ImagePullBackOff`.

**Diagnose:** `kubectl describe pod broken-1` — look at the Events section. You'll see "Failed to pull image ngnix:1.27".

<details>
<summary>Fix</summary>

The image name is misspelled: `ngnix` should be `nginx`.

```yaml
    image: nginx:1.27
```

</details>

---

## Pod 2: Invalid Port

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: broken-2
spec:
  containers:
  - name: web
    image: nginx:1.27
    ports:
    - containerPort: "eighty"
```

**Apply it:**
```bash
kubectl apply -f ../manifests/broken-pod-2.yaml
```

**What you'll see:** The API server rejects the manifest immediately with a validation error. It won't even create the Pod.

**Diagnose:** Read the error message — it tells you `containerPort` must be an integer.

<details>
<summary>Fix</summary>

`containerPort` requires an integer, not a string:

```yaml
    ports:
    - containerPort: 80
```

</details>

---

## Pod 3: Empty Containers

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: broken-3
spec:
  containers: []
```

**Apply it:**
```bash
kubectl apply -f ../manifests/broken-pod-3.yaml
```

**What you'll see:** API server rejection: "spec.containers: Required value" or "must contain at least one container".

**Diagnose:** A Pod must have at least one container. An empty array is not valid.

<details>
<summary>Fix</summary>

Add a container to the array:

```yaml
spec:
  containers:
  - name: web
    image: nginx:1.27
```

</details>

---

## Pod 4: Immediate Exit

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: broken-4
spec:
  containers:
  - name: app
    image: busybox
    command: ["echo", "hello"]
```

**Apply it:**
```bash
kubectl apply -f ../manifests/broken-pod-4.yaml
kubectl get pods -w
```

**What you'll see:** The Pod enters `CrashLoopBackOff`. It runs, prints "hello", exits 0, and restarts because the default `restartPolicy` is `Always`.

**Diagnose:**
```bash
kubectl logs broken-4        # shows "hello"
kubectl describe pod broken-4 # shows repeated restarts, exit code 0
```

The container works fine — it just finishes immediately. Kubernetes keeps restarting it.

<details>
<summary>Fix (option A): Long-running command</summary>

Replace the command with something that doesn't exit:

```yaml
    command: ["/bin/sh", "-c", "echo hello && sleep infinity"]
```

</details>

<details>
<summary>Fix (option B): Change restart policy</summary>

If you want a one-shot job, set `restartPolicy: Never`:

```yaml
spec:
  restartPolicy: Never
  containers:
  - name: app
    image: busybox
    command: ["echo", "hello"]
```

</details>

---

## Pod 5: Starved Resources

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: broken-5
spec:
  containers:
  - name: web
    image: nginx:1.27
    resources:
      limits:
        cpu: 1m
        memory: 1Mi
```

**Apply it:**
```bash
kubectl apply -f ../manifests/broken-pod-5.yaml
kubectl get pods -w
```

**What you'll see:** The Pod enters `CrashLoopBackOff` or `OOMKilled`. nginx cannot start with only 1Mi of memory.

**Diagnose:**
```bash
kubectl describe pod broken-5
```

Look for `OOMKilled` in the Last State or `Reason: OOMKilled` in the container status. 1Mi is far below what nginx needs to initialize.

<details>
<summary>Fix</summary>

Give nginx reasonable resources:

```yaml
    resources:
      limits:
        cpu: 100m
        memory: 128Mi
      requests:
        cpu: 50m
        memory: 64Mi
```

</details>

---

## Cleanup

```bash
kubectl delete pod broken-1 broken-2 broken-3 broken-4 broken-5 --ignore-not-found
```

## Key Takeaways

- `kubectl describe` Events section is your first stop for diagnosis
- `kubectl logs` shows container stdout/stderr
- API validation errors appear immediately on `kubectl apply`; runtime errors appear in Pod status
- `ImagePullBackOff` = wrong image name/tag or no network to registry
- `CrashLoopBackOff` = container starts and exits repeatedly
- `OOMKilled` = container exceeded its memory limit

## Solution Manifests

- Broken: `../manifests/broken-pod-1.yaml` through `broken-pod-5.yaml`
- Fixed: `../manifests/fixed-pod-1.yaml` through `fixed-pod-5.yaml`
