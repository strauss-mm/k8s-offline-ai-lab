# Lab 03: Pod Security Standards

## Objective

Use Kubernetes Pod Security Standards (PSS) to enforce security baselines at the namespace level. PSS replaced the deprecated PodSecurityPolicy in Kubernetes v1.25+.

## Concepts

Pod Security Standards define three profiles:

| Profile | Purpose | What it blocks |
|---------|---------|---------------|
| **privileged** | Unrestricted (default) | Nothing |
| **baseline** | Prevents known privilege escalations | hostNetwork, hostPID, privileged containers, hostPath volumes |
| **restricted** | Hardened best practices | Everything in baseline + requires non-root, drops ALL capabilities, requires seccomp |

Each profile can be applied in three modes:

| Mode | Behavior |
|------|----------|
| **enforce** | Rejects pods that violate the policy |
| **warn** | Allows the pod but prints a warning |
| **audit** | Allows the pod but logs a violation in the audit log |

## Exercise 1: Create a restricted namespace

```bash
kubectl apply -f ../manifests/namespace-restricted.yaml
```

Verify the labels:

```bash
kubectl get namespace secure-ns --show-labels
```

You should see:
```
pod-security.kubernetes.io/enforce=restricted
pod-security.kubernetes.io/warn=restricted
pod-security.kubernetes.io/audit=restricted
```

## Exercise 2: Try to deploy a privileged pod

```bash
kubectl apply -f ../manifests/pod-privileged-bad.yaml -n secure-ns
```

**Expected result**: The pod is rejected with an error like:

```
Error from server (Forbidden): error when creating "pod-privileged-bad.yaml":
pods "privileged-pod" is forbidden: violates PodSecurity "restricted:latest":
privileged (container "test" must not set securityContext.privileged=true),
...
```

Read the error carefully. It tells you exactly which fields violate the policy.

## Exercise 3: Try to deploy a root pod

Apply a pod that runs as root (UID 0) but is not privileged:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: root-pod
spec:
  containers:
    - name: test
      image: nginx:1.27
```

```bash
kubectl run root-pod --image=nginx:1.27 -n secure-ns
```

**Expected result**: Rejected. The `restricted` profile requires `runAsNonRoot: true` and an explicit `securityContext`. The default nginx image runs as root.

Read the error message and note all the violations listed.

## Exercise 4: Fix the manifest

Now create a pod that passes the `restricted` profile. Every field here is required:

```bash
kubectl apply -f ../manifests/pod-restricted-good.yaml -n secure-ns
```

### Why each field is required

| Field | Value | Why |
|-------|-------|-----|
| `runAsNonRoot: true` | Pod level | Prevents containers from running as UID 0 |
| `runAsUser: 1000` | Container level | Explicit non-root UID |
| `allowPrivilegeEscalation: false` | Container level | Prevents gaining more privileges than the parent process |
| `capabilities.drop: ["ALL"]` | Container level | Removes all Linux capabilities (restricted requires this) |
| `seccompProfile.type: RuntimeDefault` | Pod level | Applies the container runtime's default seccomp filter |
| `readOnlyRootFilesystem: true` | Container level | Not strictly required by restricted, but best practice |

### Verify it's running

```bash
kubectl get pod restricted-pod -n secure-ns
kubectl exec restricted-pod -n secure-ns -- id
# Expected: uid=1000 gid=0(root)

kubectl exec restricted-pod -n secure-ns -- whoami
# Expected: error (no whoami binary, or "I have no name!")
```

## Exercise 5: Warn mode for migration

In real clusters, you often start with `warn` to see what would break before enforcing.

```bash
kubectl create namespace migration-test
kubectl label namespace migration-test \
  pod-security.kubernetes.io/warn=restricted \
  pod-security.kubernetes.io/audit=restricted
```

Now deploy a non-compliant pod:

```bash
kubectl run test-warn --image=nginx:1.27 -n migration-test
```

**Expected**: The pod is created, but you see a warning like:

```
Warning: would violate PodSecurity "restricted:latest": ...
```

This is the recommended migration path: warn first, fix workloads, then enforce.

```bash
# After fixing all workloads, add enforcement
kubectl label namespace migration-test \
  pod-security.kubernetes.io/enforce=restricted
```

## Exercise 6: Fix a deployment

Take this Deployment and fix it to pass `restricted`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
  namespace: secure-ns
spec:
  replicas: 2
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
            - containerPort: 8080
```

**Write the fixed version yourself**, then apply it to `secure-ns` and verify all pods start.

<details>
<summary>Solution</summary>

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
  namespace: secure-ns
spec:
  replicas: 2
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      securityContext:
        runAsNonRoot: true
        seccompProfile:
          type: RuntimeDefault
      containers:
        - name: nginx
          image: nginx:1.27
          ports:
            - containerPort: 8080
          securityContext:
            runAsUser: 1000
            allowPrivilegeEscalation: false
            capabilities:
              drop:
                - ALL
            readOnlyRootFilesystem: true
          volumeMounts:
            - name: tmp
              mountPath: /tmp
            - name: cache
              mountPath: /var/cache/nginx
            - name: run
              mountPath: /var/run
      volumes:
        - name: tmp
          emptyDir: {}
        - name: cache
          emptyDir: {}
        - name: run
          emptyDir: {}
```

Nginx needs writable `/tmp`, `/var/cache/nginx`, and `/var/run` for pid files. Mount emptyDirs for these when using `readOnlyRootFilesystem`.

</details>

## Cleanup

```bash
kubectl delete namespace secure-ns migration-test
```

## Key takeaways

- Pod Security Standards are enforced via namespace labels, not separate resources
- The `restricted` profile is the gold standard for production workloads
- Use `warn` and `audit` modes to assess impact before switching to `enforce`
- Most "restricted" violations come from: missing `runAsNonRoot`, missing capability drop, missing seccomp profile
- Nginx and many images need emptyDir mounts for temp/cache/pid directories when running read-only and non-root
- `kubectl explain pod.spec.securityContext` and `kubectl explain pod.spec.containers.securityContext` are your references
