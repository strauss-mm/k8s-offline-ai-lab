# Lab 04: securityContext Deep Dive

## Objective

Configure pod and container security contexts to enforce least privilege. Verify each setting from inside the container.

## Concepts

`securityContext` exists at two levels:

- **Pod level** (`spec.securityContext`): applies to all containers, init containers, and ephemeral containers
- **Container level** (`spec.containers[].securityContext`): overrides pod-level settings for that container

## Exercise 1: Read-only root filesystem

Deploy a pod with a read-only root filesystem and verify writes are blocked:

```bash
kubectl apply -f ../manifests/pod-readonly-fs.yaml
```

### Test it

```bash
# This should fail
kubectl exec readonly-pod -- touch /etc/test-file
# Expected: touch: /etc/test-file: Read-only file system

# This should succeed (emptyDir mounted at /tmp)
kubectl exec readonly-pod -- touch /tmp/test-file
kubectl exec readonly-pod -- ls /tmp/test-file
# Expected: /tmp/test-file
```

### Why this matters

If an attacker compromises a container, they cannot:
- Write malicious scripts to disk
- Modify configuration files
- Plant backdoors in the filesystem

The application writes to `/tmp` via an emptyDir volume, which is the standard pattern.

### Write it yourself

Create a pod manifest with:
- `readOnlyRootFilesystem: true`
- An emptyDir volume mounted at `/tmp`
- Image: `busybox` with command `["sleep", "3600"]`

<details>
<summary>Verify your manifest matches</summary>

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: readonly-pod
spec:
  containers:
    - name: app
      image: busybox
      command: ["sleep", "3600"]
      securityContext:
        readOnlyRootFilesystem: true
      volumeMounts:
        - name: tmp
          mountPath: /tmp
  volumes:
    - name: tmp
      emptyDir: {}
```

</details>

## Exercise 2: Drop all capabilities, add specific ones

Linux capabilities split root's power into individual privileges. Dropping all and adding back only what's needed is least privilege.

```bash
kubectl apply -f ../manifests/pod-drop-caps.yaml
```

### Test it

```bash
# Check which capabilities the process has
kubectl exec caps-pod -- cat /proc/1/status | grep -i cap

# The CapEff (effective) line should show only NET_BIND_SERVICE
# NET_BIND_SERVICE = 0x0000000000000400

# Verify: the container can bind to port 80 (< 1024) because of NET_BIND_SERVICE
# Verify: it CANNOT do other privileged operations
kubectl exec caps-pod -- chown nobody /tmp 2>&1
# Expected: Operation not permitted (no CAP_CHOWN)
```

### Common capabilities and what they do

| Capability | Purpose | When to add |
|-----------|---------|-------------|
| NET_BIND_SERVICE | Bind to ports < 1024 | Web servers on port 80/443 |
| NET_RAW | Raw sockets (ping, tcpdump) | Network debugging only |
| CHOWN | Change file ownership | Almost never in containers |
| DAC_OVERRIDE | Bypass file permission checks | Almost never in containers |
| SETUID/SETGID | Change UID/GID | Process managers, init systems |
| SYS_PTRACE | Trace processes | Debugging only, never in prod |

### Write it yourself

Create a pod manifest that:
- Drops ALL capabilities
- Adds only NET_BIND_SERVICE
- Image: `busybox`, command: `["sleep", "3600"]`

## Exercise 3: Non-root user and group

```bash
kubectl apply -f ../manifests/pod-nonroot.yaml
```

### Test it

```bash
# Check the running user
kubectl exec nonroot-pod -- id
# Expected: uid=1000 gid=3000 groups=3000

# Check the process owner
kubectl exec nonroot-pod -- cat /proc/1/status | grep -E '^(Uid|Gid)'
# Expected: Uid: 1000 1000 1000 1000
# Expected: Gid: 3000 3000 3000 3000

# Verify cannot write to root-owned files
kubectl exec nonroot-pod -- touch /etc/test 2>&1
# Expected: Permission denied (or Read-only file system if combined with readOnlyRootFilesystem)
```

### Fields explained

| Field | Level | Effect |
|-------|-------|--------|
| `runAsUser: 1000` | Pod or container | Process runs as UID 1000 |
| `runAsGroup: 3000` | Pod or container | Process primary GID is 3000 |
| `runAsNonRoot: true` | Pod or container | Kubernetes rejects the pod if the image's USER is root |
| `fsGroup: 3000` | Pod only | Volumes are owned by GID 3000; all files get group-writable |

## Exercise 4: Seccomp profile

Seccomp (Secure Computing) filters which syscalls a container can make.

```yaml
spec:
  securityContext:
    seccompProfile:
      type: RuntimeDefault
```

The `RuntimeDefault` profile blocks dangerous syscalls like `ptrace`, `mount`, `reboot`, `kexec_load` while allowing normal application syscalls.

### Test it

```bash
# Deploy a pod with RuntimeDefault seccomp
kubectl run seccomp-test --image=busybox --restart=Never \
  --overrides='{
    "spec": {
      "securityContext": {
        "seccompProfile": {"type": "RuntimeDefault"}
      },
      "containers": [{
        "name": "test",
        "image": "busybox",
        "command": ["sleep", "3600"],
        "securityContext": {
          "allowPrivilegeEscalation": false
        }
      }]
    }
  }'

# Normal operations work fine
kubectl exec seccomp-test -- ls /
kubectl exec seccomp-test -- cat /etc/hostname
```

The `RuntimeDefault` profile is what the `restricted` Pod Security Standard requires.

## Exercise 5: Combined hardened pod

Create a single pod that combines ALL security features:

- `runAsNonRoot: true`
- `runAsUser: 1000`, `runAsGroup: 3000`, `fsGroup: 3000`
- `readOnlyRootFilesystem: true`
- `allowPrivilegeEscalation: false`
- `capabilities.drop: ["ALL"]`
- `seccompProfile.type: RuntimeDefault`
- emptyDir at `/tmp`

**Write this yourself**, then verify:

```bash
kubectl exec hardened-pod -- id
# uid=1000 gid=3000 groups=3000

kubectl exec hardened-pod -- touch /etc/test 2>&1
# Read-only file system

kubectl exec hardened-pod -- touch /tmp/works
# Success

kubectl exec hardened-pod -- cat /proc/1/status | grep Cap
# CapEff should be 0000000000000000 (no capabilities)
```

<details>
<summary>Solution</summary>

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: hardened-pod
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    runAsGroup: 3000
    fsGroup: 3000
    seccompProfile:
      type: RuntimeDefault
  containers:
    - name: app
      image: busybox
      command: ["sleep", "3600"]
      securityContext:
        readOnlyRootFilesystem: true
        allowPrivilegeEscalation: false
        capabilities:
          drop:
            - ALL
      volumeMounts:
        - name: tmp
          mountPath: /tmp
  volumes:
    - name: tmp
      emptyDir: {}
```

</details>

## Cleanup

```bash
kubectl delete pod readonly-pod caps-pod nonroot-pod seccomp-test hardened-pod --ignore-not-found
```

## Key takeaways

- `readOnlyRootFilesystem` blocks disk-based attacks; use emptyDir for temp files
- Always drop ALL capabilities, then add back only what's specifically needed
- `runAsNonRoot: true` is a safety net; `runAsUser` sets the actual UID
- `fsGroup` ensures mounted volumes are group-accessible to the pod's processes
- `allowPrivilegeEscalation: false` prevents setuid binaries from gaining root
- `seccompProfile: RuntimeDefault` blocks dangerous syscalls with minimal app impact
- Combining all of these produces a defense-in-depth container runtime configuration
