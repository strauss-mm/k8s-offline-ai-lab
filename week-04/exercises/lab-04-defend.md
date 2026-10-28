# Lab 04: Defend — Fix Every Attack Vector

## Objective

Remediate every vulnerability discovered in Lab 03. For each attack, apply the defense, then verify the attack no longer works.

---

## Setup

Recreate the target environment:

```bash
kubectl create namespace target
kubectl -n target create deployment web --image=nginx:1.27 --replicas=2
kubectl -n target expose deployment web --port=80
kubectl -n target create secret generic db-creds \
  --from-literal=username=admin \
  --from-literal=password='S3cretP@ssw0rd!'
```

---

## Defense 1: Pod Security Standards — Block Privileged Containers

**Blocks**: Attack 1 (Privileged Container Escape)

### Concept

Pod Security Standards (PSS) define three profiles:
- **Privileged**: Unrestricted (allows everything)
- **Baseline**: Prevents known privilege escalations
- **Restricted**: Hardened (no root, no host access, drop all capabilities)

PSS is enforced per-namespace using labels. No additional controllers needed.

### Apply

Label the target namespace to enforce the restricted profile:

```bash
kubectl apply -f manifests/defend-pss-namespace.yaml
```

Or apply inline:

```bash
kubectl label namespace target \
  pod-security.kubernetes.io/enforce=restricted \
  pod-security.kubernetes.io/warn=restricted \
  pod-security.kubernetes.io/audit=restricted \
  --overwrite
```

### Verify

Try to deploy a privileged Pod in the target namespace:

```bash
kubectl -n target apply -f manifests/attack-privileged-pod.yaml
```

Expected output:
```
Error from server (Forbidden): pods "privileged-attacker" is forbidden: 
violates PodSecurity "restricted:latest": privileged (container "attacker" 
must not set securityContext.privileged=true), ...
```

The API server rejects the Pod at admission. The attack is blocked before the container even starts.

Also verify that Pods with `hostPID`, `hostNetwork`, or `hostIPC` are rejected:

```bash
kubectl -n target run host-test --image=busybox --overrides='
{"spec":{"hostPID":true,"containers":[{"name":"test","image":"busybox","command":["sleep","10"]}]}}' 2>&1
```

This should also be rejected.

---

## Defense 2: Disable Auto-mounted Service Account Tokens

**Blocks**: Attack 2 (Service Account Token Theft)

### Concept

Set `automountServiceAccountToken: false` on the ServiceAccount or Pod spec. Pods that do not need API access should not have a token.

For Pods that need API access, create a dedicated ServiceAccount with minimal RBAC.

### Apply

```bash
kubectl apply -f manifests/defend-no-automount.yaml
```

This creates:
- A ServiceAccount with `automountServiceAccountToken: false`
- A Pod using that ServiceAccount

### Verify

```bash
kubectl -n target wait --for=condition=Ready pod/no-token-pod --timeout=30s

# Check that no token is mounted
kubectl -n target exec no-token-pod -- ls /var/run/secrets/kubernetes.io/serviceaccount/ 2>&1
```

Expected output:
```
ls: /var/run/secrets/kubernetes.io/serviceaccount/: No such file or directory
```

No token means no API access from inside the Pod:

```bash
kubectl -n target exec no-token-pod -- sh -c \
  'wget -q --timeout=2 -O - https://kubernetes.default.svc/api/v1/pods 2>&1' || true
```

This fails because there is no credential to authenticate with.

### For Pods That Need API Access

Create a minimal RBAC binding:

```bash
kubectl -n target create serviceaccount app-reader
kubectl -n target create role pod-reader --verb=get,list --resource=pods
kubectl -n target create rolebinding app-reader-binding \
  --role=pod-reader --serviceaccount=target:app-reader
```

Then reference the ServiceAccount in the Pod spec but do NOT set `automountServiceAccountToken: false`. The token will be mounted, but it can only read Pods in the target namespace — nothing else.

---

## Defense 3: Restrict Secret Access with RBAC

**Blocks**: Attack 3 (Exposed Secrets)

### Concept

Kubernetes Secrets are base64-encoded, not encrypted. The primary defense is RBAC: limit who (users and ServiceAccounts) can read Secrets.

Additional measures:
- Enable encryption at rest (EncryptionConfiguration on the API server)
- Use external secret managers (Vault, AWS Secrets Manager) to keep secrets out of etcd entirely
- Rotate credentials regularly

### Apply

Ensure the default ServiceAccount cannot read Secrets:

```bash
# Check current access (should be "no" on a fresh cluster)
kubectl auth can-i get secrets -n target --as=system:serviceaccount:target:default

# If it returns "yes", there's an overly broad binding. Find and remove it:
kubectl get clusterrolebindings -o json | \
  python3 -c "
import json, sys
data = json.load(sys.stdin)
for b in data['items']:
  for s in b.get('subjects', []):
    if s.get('name') == 'default' and s.get('kind') == 'ServiceAccount':
      print(f\"REVIEW: {b['metadata']['name']}\")
" 2>/dev/null
```

Create a strict policy: only a dedicated `secrets-reader` SA can read secrets, and only in its own namespace:

```bash
kubectl -n target create serviceaccount secrets-reader
kubectl -n target create role secret-access --verb=get --resource=secrets
kubectl -n target create rolebinding secret-access-binding \
  --role=secret-access --serviceaccount=target:secrets-reader
```

### Verify

```bash
# Default SA cannot read secrets
kubectl auth can-i get secrets -n target --as=system:serviceaccount:target:default
# Expected: no

# Dedicated SA can
kubectl auth can-i get secrets -n target --as=system:serviceaccount:target:secrets-reader
# Expected: yes

# Cross-namespace access blocked
kubectl auth can-i get secrets -n kube-system --as=system:serviceaccount:target:secrets-reader
# Expected: no
```

---

## Defense 4: Default-Deny NetworkPolicy

**Blocks**: Attack 4 (Full Mesh / Lateral Movement)

### Concept

Without NetworkPolicies, all Pods can talk to all Pods. A default-deny policy blocks all traffic, then you add explicit allow rules for legitimate communication paths.

**Prerequisite**: kind uses kindnet by default, which does NOT enforce NetworkPolicies. To test enforcement, recreate your cluster with Calico. See Week 3 setup, or:

```bash
kind delete cluster
cat <<'EOF' | kind create cluster --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
networking:
  disableDefaultCNI: true
  podSubnet: "10.244.0.0/16"
nodes:
- role: control-plane
- role: worker
EOF

# Install Calico (pre-download the manifest while online)
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.28.0/manifests/calico.yaml
# Wait for Calico to be ready
kubectl -n kube-system wait --for=condition=Ready pods -l k8s-app=calico-node --timeout=120s

# Reload images
kind load docker-image nginx:1.27 busybox redis:7
```

### Apply

```bash
kubectl apply -f manifests/defend-netpol-default-deny.yaml
```

This creates:
- A default-deny ingress policy in the target namespace
- A default-deny egress policy in the target namespace

### Add Explicit Allow Rules

Allow only DNS egress (so Pods can resolve service names) and specific service-to-service traffic:

```bash
# Allow DNS resolution (required for most workloads)
kubectl -n target apply -f - <<'EOF'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-dns
spec:
  podSelector: {}
  policyTypes:
  - Egress
  egress:
  - to:
    - namespaceSelector: {}
    ports:
    - protocol: UDP
      port: 53
    - protocol: TCP
      port: 53
EOF
```

### Verify

Deploy an attacker Pod in the default namespace and try to reach the target:

```bash
kubectl run netpol-test --image=busybox --command -- sleep 3600
kubectl wait --for=condition=Ready pod/netpol-test --timeout=30s

TARGET_IP=$(kubectl -n target get svc web -o jsonpath='{.spec.clusterIP}')
kubectl exec netpol-test -- wget -q -O - --timeout=3 http://$TARGET_IP 2>&1
```

With Calico enforcing, this should time out. Without Calico (kindnet), it still reaches — which is why the CNI matters.

```bash
kubectl delete pod netpol-test
```

---

## Defense 5: Security Context — Non-root, Read-only, Drop Capabilities

**Blocks**: Attack 5 (Running as Root)

### Concept

The `securityContext` field on Pods and containers controls:
- `runAsNonRoot: true` — container must run as a non-root user
- `runAsUser: 1000` — explicit UID
- `readOnlyRootFilesystem: true` — container cannot write to its filesystem
- `allowPrivilegeEscalation: false` — no setuid/setgid
- `capabilities.drop: ["ALL"]` — remove all Linux capabilities

### Apply

```bash
kubectl apply -f manifests/defend-security-context.yaml
```

### Verify

```bash
kubectl -n target wait --for=condition=Ready pod/hardened-nginx --timeout=30s

# Check the user
kubectl -n target exec hardened-nginx -- id
# Expected: uid=101(nginx) — not root

# Try to write to the filesystem
kubectl -n target exec hardened-nginx -- touch /tmp/test 2>&1
# Expected: Read-only file system (if readOnlyRootFilesystem is true)
# Note: nginx needs /var/cache/nginx and /var/run writable, handled by emptyDir mounts

# Check capabilities
kubectl -n target exec hardened-nginx -- sh -c 'cat /proc/1/status | grep Cap' 2>&1
# CapEff should show 0000000000000000 (no effective capabilities)
```

Compare with the attack Pod:

```bash
kubectl apply -f manifests/attack-root-pod.yaml
kubectl wait --for=condition=Ready pod/root-pod --timeout=30s
kubectl exec root-pod -- id
# uid=0(root)
kubectl exec root-pod -- touch /root/pwned
# Success — writable as root
kubectl delete pod root-pod
```

---

## Defense Summary

| Attack | Defense | How to Verify |
|--------|---------|---------------|
| Privileged escape | PSS restricted namespace | API rejects privileged Pods |
| SA token theft | automountServiceAccountToken: false | No token mounted |
| Exposed secrets | RBAC restrict get secrets | auth can-i returns no |
| Full mesh | Default-deny NetworkPolicy + Calico | Cross-namespace traffic times out |
| Running as root | securityContext hardening | id returns non-root UID |

---

## Cleanup

```bash
kubectl delete namespace target
kubectl delete pod root-pod 2>/dev/null
```

## AI Exercises

Ask your local LLM:
- "Generate a comprehensive securityContext for a production Java application Pod"
- "Explain the PSS restricted profile — what does it block and why?"
- "What is the difference between a Role and a ClusterRole for secret access?"
- "Design a NetworkPolicy that allows a frontend to talk to a backend, and the backend to talk to a database, with no other traffic"

Verify generated YAML with `kubectl apply --dry-run=client -f file.yaml`.
