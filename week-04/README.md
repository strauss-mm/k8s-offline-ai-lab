# Week 4: Operations and Attack/Defend

The final week combines operational skills with security offense and defense. You will learn how Kubernetes keeps applications healthy under disruption, how to package applications with Helm, and then attack your own cluster to find real vulnerabilities — then fix every one of them. The week ends with a capstone that ties together everything from all four weeks.

## Objectives

- Configure liveness and readiness probes
- Understand HorizontalPodAutoscaler concepts (limited offline)
- Use PodDisruptionBudgets and node drain
- Install and author Helm charts
- Execute five attack scenarios against your cluster
- Remediate every attack with hardened configurations
- Deploy a fully secured 3-tier application as a capstone

## Daily Plan

| Day | Topic | Lab | Time |
|-----|-------|-----|------|
| 1 | Operations: probes, PDB, drain | [lab-01](exercises/lab-01-operations.md) | 60 min |
| 2 | Helm: install, author, upgrade | [lab-02](exercises/lab-02-helm.md) | 60 min |
| 3 | Attack your own cluster | [lab-03](exercises/lab-03-attack.md) | 60 min |
| 4 | Defend: fix every attack vector | [lab-04](exercises/lab-04-defend.md) | 60 min |
| 5 | Capstone: secured 3-tier app | [lab-05](exercises/lab-05-capstone.md) | 90 min |

## Pre-pull Images (while online)

```bash
docker pull nginx:1.27
docker pull busybox
docker pull redis:7
kind load docker-image nginx:1.27 busybox redis:7
```

These are the same images used in earlier weeks. If you already loaded them, skip this step.

## Key References

- `kubectl explain pod.spec.containers.livenessProbe`
- `kubectl explain poddisruptionbudget.spec`
- `kubectl explain networkpolicy.spec`
- `kubectl explain pod.spec.securityContext`
- Saved offline docs: `kubernetes.io/docs/concepts/workloads/pods/pod-lifecycle/`
- Saved offline docs: `kubernetes.io/docs/concepts/security/pod-security-standards/`

## Manifests

All YAML files for this week are in the [manifests/](manifests/) directory. Try writing them yourself first, then compare with the provided solutions.
