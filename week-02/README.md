# Week 2: Config, Storage, Networking

Master application configuration, persistent storage, resource management, and traffic routing — all on your offline kind cluster with a local AI tutor.

## Objectives

By end of week you can:

- Create and consume ConfigMaps and Secrets in Pods (env vars and volume mounts)
- Provision PersistentVolumes and PersistentVolumeClaims; prove data survives Pod deletion
- Isolate workloads with Namespaces and enforce limits with ResourceQuotas and LimitRanges
- Install ingress-nginx offline and route traffic to multiple backends by path

## Prerequisites

- Week 1 completed (working kind cluster, comfortable with Pods, Deployments, Services)
- Images pre-pulled and loaded into kind:
  ```bash
  docker pull nginx:1.27 busybox
  kind load docker-image nginx:1.27 busybox
  ```
- For Day 4 (Ingress), pre-pull the ingress-nginx controller:
  ```bash
  docker pull registry.k8s.io/ingress-nginx/controller:v1.11.3
  docker pull registry.k8s.io/ingress-nginx/kube-webhook-certgen:v1.4.4
  kind load docker-image registry.k8s.io/ingress-nginx/controller:v1.11.3
  kind load docker-image registry.k8s.io/ingress-nginx/kube-webhook-certgen:v1.4.4
  ```

## Day-by-Day Plan

| Day | Topic | Lab | Key Commands |
|-----|-------|-----|-------------|
| 1 | ConfigMaps and Secrets | [lab-01](exercises/lab-01-configmaps-secrets.md) | `kubectl create configmap`, `kubectl create secret` |
| 2 | PersistentVolumes and PVCs | [lab-02](exercises/lab-02-storage.md) | `kubectl get pv`, `kubectl get pvc` |
| 3 | Namespaces, Quotas, Limits | [lab-03](exercises/lab-03-namespaces-quotas.md) | `kubectl create ns`, `kubectl describe quota` |
| 4 | Ingress | [lab-04](exercises/lab-04-ingress.md) | `kubectl get ingress`, `curl` |
| 5 | Review + AI Quiz | [lab-05](exercises/lab-05-challenge.md) | Everything from this week |

## Daily Rhythm (1 hour)

| Block | Time | Activity |
|-------|------|----------|
| Read | 10 min | `kubectl explain` the day's resource (e.g., `kubectl explain pv.spec`) |
| Lab | 40 min | Complete the exercise, YAML by hand |
| AI Review | 10 min | Paste your YAML into the local LLM for review or quiz |

## AI Prompts for This Week

Use these with `ollama run gemma4-k8s` or your preferred model:

- "Explain the difference between ConfigMaps and Secrets in Kubernetes. When would you use each?"
- "I mounted a ConfigMap as a volume. If I update the ConfigMap, does the Pod see the new values? Explain."
- "What happens if a PVC requests more storage than any PV can provide?"
- "Give me a broken Ingress manifest and tell me to find the errors."
- "Quiz me on Kubernetes storage: 5 questions about PVs, PVCs, access modes, and reclaim policies."

## Key Concepts

**ConfigMaps** store non-sensitive configuration (key-value pairs, files). Consumed as env vars or mounted volumes. Updated ConfigMaps propagate to volume-mounted Pods (with a delay), but NOT to env vars — that requires a Pod restart.

**Secrets** store sensitive data (base64-encoded at rest in etcd, decoded when mounted). Types: Opaque, kubernetes.io/tls, kubernetes.io/dockerconfigjson. Same consumption patterns as ConfigMaps.

**PersistentVolumes (PV)** are cluster-scoped storage resources. **PersistentVolumeClaims (PVC)** are namespace-scoped requests for storage. A PVC binds to a PV that satisfies its access mode and capacity requirements.

**ResourceQuotas** limit total resource consumption per namespace. **LimitRanges** set per-Pod/container defaults and constraints.

**Ingress** routes external HTTP/HTTPS traffic to Services based on host or path rules. Requires an Ingress controller (we use ingress-nginx).

## Solution Manifests

All solution YAML files are in [manifests/](manifests/). Apply any of them with:

```bash
kubectl apply -f manifests/<filename>.yaml
```
