# Week 1: Core Objects

Master the foundational Kubernetes objects — Pods, Deployments, and Services — and the kubectl commands you'll use every day.

## Objectives

By the end of this week you should be able to:

- Create, inspect, and delete Pods using both manifests and imperative commands
- Diagnose common Pod failures from events, logs, and describe output
- Manage Deployments: create, scale, update, and rollback
- Expose workloads with ClusterIP and NodePort Services
- Navigate the built-in docs with `kubectl explain`

## Prerequisites

- kind cluster running (`kind create cluster`)
- Images pre-pulled for offline use: `nginx:1.27`, `busybox`, `redis:7`
- Load them into kind: `kind load docker-image nginx:1.27 busybox redis:7`

## Daily Schedule

| Day | Topic | Lab |
|-----|-------|-----|
| 1 | Pods and kubectl basics | [lab-01-pods](exercises/lab-01-pods.md) |
| 2 | Pod troubleshooting (broken manifests) | [lab-02-broken-pods](exercises/lab-02-broken-pods.md) |
| 3 | Deployments, replicas, rolling updates, rollbacks | [lab-03-deployments](exercises/lab-03-deployments.md) |
| 4 | Services (ClusterIP, NodePort) | [lab-04-services](exercises/lab-04-services.md) |
| 5 | Review and AI-generated challenge | [lab-05-challenge](exercises/lab-05-challenge.md) |

## Key Commands

```bash
# Pod lifecycle
kubectl run nginx --image=nginx:1.27
kubectl get pods -o wide
kubectl describe pod <name>
kubectl logs <name> [-c container]
kubectl exec -it <name> -- /bin/sh
kubectl delete pod <name>

# Deployments
kubectl create deployment nginx --image=nginx:1.27 --replicas=3
kubectl scale deployment nginx --replicas=5
kubectl set image deployment/nginx nginx=nginx:1.27-alpine
kubectl rollout status deployment/nginx
kubectl rollout undo deployment/nginx
kubectl rollout history deployment/nginx

# Services
kubectl expose deployment nginx --port=80 --target-port=80 --type=ClusterIP
kubectl expose deployment nginx --port=80 --target-port=80 --type=NodePort
kubectl get svc

# Manifest generation (offline-friendly)
kubectl run nginx --image=nginx:1.27 --dry-run=client -o yaml > pod.yaml
kubectl create deployment nginx --image=nginx:1.27 --dry-run=client -o yaml > deploy.yaml

# Built-in docs — works fully offline
kubectl explain pod.spec.containers
kubectl explain deployment.spec.strategy
kubectl explain service.spec.type
```

## Offline Docs Tip

`kubectl explain` is your offline reference manual. It documents every field in the Kubernetes API:

```bash
kubectl explain pod                         # top-level fields
kubectl explain pod.spec                    # Pod spec
kubectl explain pod.spec.containers         # container fields
kubectl explain pod.spec.containers.ports   # port fields
kubectl explain --recursive pod.spec        # full tree (long output)
```

Pair this with `kubectl <command> --help` for usage examples. Between `explain` and `--help`, you rarely need the website.

## AI Tutor Prompts

Ask your local LLM these to reinforce learning:

- "Explain the difference between a Pod and a container in Kubernetes"
- "What happens when I delete a Pod managed by a Deployment?"
- "Give me 5 broken Pod manifests to debug" (then actually debug them)
- "Quiz me on kubectl commands for Pod management"
- "Review this YAML for mistakes: [paste your manifest]"

Always verify AI output: `kubectl apply --dry-run=client -f file.yaml`

## Solution Manifests

All lab solutions are in the [manifests/](manifests/) directory as standalone YAML files ready to apply.
