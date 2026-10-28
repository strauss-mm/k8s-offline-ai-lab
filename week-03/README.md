# Week 3: Security Hardening

This week focuses on Kubernetes security primitives. As a security engineer, these are the controls you'll use daily to harden clusters, enforce least privilege, and detect misconfigurations.

## Prerequisites

- Completed Weeks 1 and 2
- Calico CNI required for NetworkPolicy enforcement (kind's default CNI does not enforce policies)
- Pre-downloaded trivy and kubescape databases for offline scanning

### Recreate cluster with Calico

```bash
kind delete cluster
kind create cluster --config ../setup/kind-calico.yaml
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.0/manifests/calico.yaml
# Wait for Calico to be ready
kubectl -n kube-system wait --for=condition=Ready pod -l k8s-app=calico-node --timeout=120s
```

Save the Calico manifest offline before going air-gapped:
```bash
curl -Lo calico.yaml https://raw.githubusercontent.com/projectcalico/calico/v3.27.0/manifests/calico.yaml
```

## Objectives

By the end of this week you will be able to:

- Write and apply NetworkPolicies to control pod-to-pod traffic
- Configure RBAC with ServiceAccounts, Roles, and ClusterRoles
- Enforce Pod Security Standards at the namespace level
- Harden pods with securityContext settings
- Scan manifests and clusters with trivy and kubescape

## Schedule

| Day | Topic | Lab | Key Concepts |
|-----|-------|-----|-------------|
| 1 | NetworkPolicies | [lab-01](exercises/lab-01-network-policies.md) | Default deny, ingress/egress rules, label selectors |
| 2 | RBAC | [lab-02](exercises/lab-02-rbac.md) | ServiceAccounts, Roles, RoleBindings, ClusterRoles, `auth can-i` |
| 3 | Pod Security Standards | [lab-03](exercises/lab-03-pod-security.md) | Namespace labels, enforce/warn/audit modes, restricted profile |
| 4 | securityContext | [lab-04](exercises/lab-04-security-context.md) | Non-root, read-only filesystem, capabilities, seccomp |
| 5 | Scanning + Challenge | [lab-05](exercises/lab-05-scanning-challenge.md) | trivy config, kubescape, fix-and-rescan workflow |

## AI Tutor Prompts

Use these with your local LLM (Ollama) to reinforce learning:

```
"Explain the difference between a Role and a ClusterRole in Kubernetes RBAC. When would I use each?"

"I have a 3-tier app (frontend, backend, database). Write me NetworkPolicies that enforce: frontend can only reach backend, backend can only reach database, database accepts connections only from backend."

"What are the Pod Security Standards levels (privileged, baseline, restricted)? What does each one block?"

"Give me 5 broken RBAC manifests to debug. Include common mistakes like wrong API group, missing verbs, or binding to a non-existent role."

"Review this securityContext and tell me what's still insecure: {paste your YAML}"
```

## Manifests

All manifests for this week are in [manifests/](manifests/). Apply them with:

```bash
kubectl apply -f manifests/<filename>.yaml
```
