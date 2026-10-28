# Lab 05: Scanning and Capstone Challenge

## Objective

Use trivy and kubescape to scan manifests and running clusters for security misconfigurations. Then complete a capstone challenge: deploy an intentionally insecure app, identify all issues, fix them, and verify with a clean rescan.

## Prerequisites: Offline database setup

Download these while you still have internet access:

### Trivy

```bash
# Download trivy vulnerability database
trivy image --download-db-only

# Download trivy config/misconfiguration checks
trivy image --download-java-db-only

# Cache location (reuse offline)
ls ~/.cache/trivy/
```

### Kubescape

```bash
# Download the NSA/CISA framework
kubescape download framework nsa -o nsa-framework.json

# Download all artifacts for offline use
kubescape download artifacts --output ~/.kubescape/
```

### Verify offline mode

```bash
# Disconnect from network, then:
trivy config --skip-db-update --skip-java-db-update .
kubescape scan framework nsa --use-artifacts-from ~/.kubescape/
```

## Exercise 1: Scan manifests with trivy

Scan the week's manifests for misconfigurations:

```bash
cd ../manifests/

# Scan all YAML files in the directory
trivy config --skip-db-update .
```

Trivy checks for:
- Running as root
- Missing security contexts
- Privileged containers
- Missing resource limits
- Writable root filesystem
- Missing network policies

### Review the output

For each finding, trivy shows:
- **Severity**: CRITICAL, HIGH, MEDIUM, LOW
- **Rule ID**: The specific check (e.g., KSV001 = process can elevate privileges)
- **Message**: What's wrong
- **Resolution**: How to fix it

Scan specific files:

```bash
trivy config --skip-db-update pod-privileged-bad.yaml
trivy config --skip-db-update pod-restricted-good.yaml
```

Compare the finding counts. The restricted pod should have significantly fewer (ideally zero) findings.

## Exercise 2: Scan a running cluster with kubescape

```bash
# Scan against the NSA/CISA Kubernetes hardening guide
kubescape scan framework nsa --use-artifacts-from ~/.kubescape/

# Scan against MITRE ATT&CK
kubescape scan framework mitre --use-artifacts-from ~/.kubescape/
```

### Understand the output

Kubescape reports:
- **Controls**: Individual security checks (e.g., "Immutable container filesystem")
- **Resources**: Which pods/deployments fail each control
- **Risk score**: Overall cluster security posture (0-100, lower is better)

Focus on failed controls. For each one:
1. Read the description
2. Identify which workloads fail
3. Plan the fix

## Exercise 3: Scan specific workloads

```bash
# Scan a specific namespace
kubescape scan framework nsa --include-namespaces default --use-artifacts-from ~/.kubescape/

# Scan specific YAML files
kubescape scan framework nsa ../manifests/frontend-deploy.yaml --use-artifacts-from ~/.kubescape/
```

## Exercise 4: Fix and rescan loop

Pick three findings from your scan. For each one:

1. Note the control name and affected resource
2. Edit the manifest to fix it
3. Reapply: `kubectl apply -f <manifest>`
4. Rescan and verify the finding is gone

This is the core workflow for security hardening: scan, fix, verify, repeat.

---

## Capstone Challenge: Secure the insecure app

### The scenario

You've inherited a 3-tier application deployed by a developer who prioritized speed over security. Your job: find every security issue, fix it, and prove the fix with a clean scan.

### Step 1: Deploy the insecure app

```bash
kubectl create namespace insecure-app
kubectl apply -f ../manifests/insecure-app.yaml -n insecure-app
kubectl get pods -n insecure-app
```

### Step 2: Audit the deployment

Run all your scanning tools:

```bash
# Static scan of the manifest
trivy config --skip-db-update ../manifests/insecure-app.yaml

# Runtime scan of the namespace
kubescape scan framework nsa --include-namespaces insecure-app --use-artifacts-from ~/.kubescape/
```

Also do a manual review. Check for:

```bash
# Are any pods running as root?
kubectl get pods -n insecure-app -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[*].securityContext}{"\n"}{end}'

# Are there any NetworkPolicies?
kubectl get networkpolicy -n insecure-app

# Are there any resource limits?
kubectl get pods -n insecure-app -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[*].resources}{"\n"}{end}'

# What ServiceAccount are pods using?
kubectl get pods -n insecure-app -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.serviceAccountName}{"\n"}{end}'
```

### Step 3: Document all findings

Before fixing anything, write down every issue you found. You should find at least these:

| # | Finding | Severity |
|---|---------|----------|
| 1 | Containers running as root | Critical |
| 2 | Privileged security context | Critical |
| 3 | No NetworkPolicies (flat network) | High |
| 4 | Capabilities not dropped | High |
| 5 | No seccomp profile | High |
| 6 | allowPrivilegeEscalation not set to false | High |
| 7 | Writable root filesystem | Medium |
| 8 | No resource requests/limits | Medium |
| 9 | Using default ServiceAccount | Medium |
| 10 | No Pod Security Standards on namespace | Medium |

### Step 4: Fix everything

Apply the secure version:

```bash
kubectl delete namespace insecure-app
kubectl apply -f ../manifests/secure-app.yaml
```

Or better yet, write the fixes yourself. Use the insecure manifest as a starting point and fix each issue. Then compare your work with `secure-app.yaml`.

### Step 5: Verify with a clean scan

```bash
# Static scan
trivy config --skip-db-update ../manifests/secure-app.yaml

# Runtime scan
kubescape scan framework nsa --include-namespaces secure-app --use-artifacts-from ~/.kubescape/
```

The secure version should have zero CRITICAL and zero HIGH findings.

### Step 6: Verify runtime behavior

```bash
SECURE_POD=$(kubectl get pod -n secure-app -l app=web -o jsonpath='{.items[0].metadata.name}')

# Running as non-root
kubectl exec $SECURE_POD -n secure-app -- id
# Expected: uid=1000

# Cannot write to root filesystem
kubectl exec $SECURE_POD -n secure-app -- touch /etc/test 2>&1
# Expected: Read-only file system

# No capabilities
kubectl exec $SECURE_POD -n secure-app -- cat /proc/1/status | grep CapEff
# Expected: 0000000000000000

# NetworkPolicy blocks unexpected traffic
kubectl run probe --image=busybox --restart=Never -n secure-app -- wget -qO- --timeout=3 http://web 2>&1
# Expected: timeout (no ingress rule allowing from arbitrary pods)
```

## Cleanup

```bash
kubectl delete namespace insecure-app secure-app --ignore-not-found
```

## Key takeaways

- Scanning should be part of every deployment pipeline, not an afterthought
- Static scanning (trivy config) catches issues before deployment
- Runtime scanning (kubescape) catches issues that depend on cluster state
- The fix-and-rescan loop is the fundamental workflow for hardening
- Defense in depth: no single control is sufficient, layer them all
- Always verify fixes both with scanning tools AND manual runtime checks
