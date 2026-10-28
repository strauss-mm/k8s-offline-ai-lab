# Learn Kubernetes with Offline AI on Kali Linux

A 4-week hands-on lab plan using local LLMs and kind clusters — no internet required after setup.

## Hardware Requirements

| Resource | Minimum | Recommended |
|----------|---------|-------------|
| RAM | 8 GB | 16 GB |
| Disk | 20 GB free | 40 GB free |
| CPU | 4 cores | 8 cores |
| GPU | Not required | Any (Ollama uses it automatically) |

8 GB RAM can run the 3B models and a single-node kind cluster. 16 GB lets you run 8B models comfortably alongside the cluster.

## Quick Start (requires internet once)

Run these three scripts in order. After that, everything works offline.

```bash
git clone https://github.com/strauss-mm/k8s-offline-ai-lab.git
cd k8s-offline-ai-lab

# Step 1: Install Ollama and pull models (~15 min depending on connection)
./setup/install-ollama.sh

# Step 2: Install Docker, kubectl, kind and create a cluster (~5 min)
./setup/install-cluster.sh

# Step 3: Pre-pull container images for offline labs (~5 min)
./setup/prepull-images.sh
```

Verify everything:
```bash
ollama run gemma4-k8s "What is a Kubernetes Pod?"
kubectl get nodes
kubectl run test --image=nginx:1.27 --dry-run=client -o yaml
```

## Ollama Model Setup

Three models, each with different strengths:

| Model | Size | RAM Needed | Best For |
|-------|------|-----------|----------|
| `llama3.1:8b` | ~4.7 GB | ~8 GB | General explanations, conceptual questions, troubleshooting walkthroughs |
| `qwen2.5-coder:7b` | ~4.4 GB | ~8 GB | YAML generation, code review, spotting syntax errors in manifests |
| `gemma4:e4b` | ~2.5 GB | ~4 GB | Fast responses, good for quizzes and quick lookups, lowest resource use |

If RAM is tight, use `llama3.2:3b` or `gemma4:e2b` instead.

### Fix the context window

Ollama defaults Gemma 4 to a 4K context window — too small for pasting `kubectl describe` output. The install script creates a larger-context version:

```bash
cat > /tmp/Modelfile <<'EOF'
FROM gemma4:e4b
PARAMETER num_ctx 16384
EOF
ollama create gemma4-k8s -f /tmp/Modelfile
ollama run gemma4-k8s
```

Raise `num_ctx` if you have spare RAM; larger values use more memory.

## Local Cluster Setup

The install script sets up a single-node kind cluster on Kali. For Week 3 (NetworkPolicy labs), you'll recreate it with Calico CNI:

```bash
# Standard cluster (Weeks 1, 2, 4)
./setup/reset-cluster.sh

# Calico cluster (Week 3 — NetworkPolicy enforcement)
./setup/reset-cluster.sh --calico
```

### Pre-pulled images for offline use

The cluster can only run images already loaded. The prepull script loads:

- `nginx:1.27`, `busybox`, `redis:7` — lab workloads
- `calico/cni`, `calico/node`, `calico/kube-controllers` — Week 3 CNI
- `registry.k8s.io/ingress-nginx/controller` — Week 2 Ingress

## 4-Week Overview

| Week | Theme | Key Topics | Labs |
|------|-------|-----------|------|
| 1 | Core Objects | Pods, Deployments, Services, kubectl basics | 5 labs + 5 broken manifests |
| 2 | Config, Storage, Networking | ConfigMaps, Secrets, PV/PVC, Namespaces, Ingress | 5 labs + 5 broken manifests |
| 3 | Security Hardening | NetworkPolicy, RBAC, Pod Security Standards, securityContext, scanning | 6 labs + 5 broken manifests |
| 4 | Operations & Attack/Defend | Probes, HPA, Helm, attack scenarios, capstone | 5 labs + capstone |

## Daily Rhythm (1 hour)

| Block | Duration | Activity |
|-------|----------|----------|
| Read | 10 min | Study the concept. Use `kubectl explain` and saved docs. |
| Lab | 40 min | Complete the day's exercise. Write YAML by hand. |
| AI Review | 10 min | Ask the LLM to review your work, quiz you, or explain errors. |

## Rules That Make It Stick

1. **Write YAML yourself.** Use the AI only for review and exercises — not to generate your manifests.
2. **Reset often.** `./setup/reset-cluster.sh` gives you a clean slate. Don't debug cluster state from 3 labs ago.
3. **Keep a notes.md.** Record every error and its fix. This is your real study material.
4. **Verify AI output.** Always run `kubectl apply --dry-run=client -f file.yaml`. Small models hallucinate API fields.
5. **Use `kubectl explain` constantly.** It's built-in offline documentation: `kubectl explain pod.spec.containers`.

## Using the AI Well

**Do:**
- Ask it to generate broken manifests for you to debug
- Paste `kubectl describe` and `kubectl logs` output for troubleshooting help
- Ask it to quiz you on a topic after you've studied it
- Ask it to review your YAML for security issues

**Don't:**
- Copy-paste its YAML without reading it — validate with `--dry-run=client`
- Trust it on exact API field names — `kubectl explain` is authoritative
- Use it as a substitute for hands-on practice
- Ask it to solve the lab for you

**Useful prompt patterns:**
```
"Give me 5 broken Pod manifests to debug — don't tell me what's wrong"
"I got this error: [paste error]. What should I check?"
"Quiz me on Kubernetes Services — 5 questions, wait for my answers"
"Review this YAML for security best practices: [paste YAML]"
"Explain the difference between a ClusterIP and a NodePort Service"
```

## Saving Docs for Offline Use

While online, download the Kubernetes docs:

```bash
wget -r -np -k -l 3 https://kubernetes.io/docs/concepts/
wget -r -np -k -l 3 https://kubernetes.io/docs/tasks/
```

Or rely on `kubectl explain` — it covers every API field and works fully offline.

## Repository Structure

```
k8s-offline-ai-lab/
├── README.md
├── setup/
│   ├── install-ollama.sh         # Install Ollama + pull models
│   ├── install-cluster.sh        # Install Docker + kubectl + kind
│   ├── prepull-images.sh         # Pre-pull images for offline use
│   ├── reset-cluster.sh          # Destroy and recreate cluster
│   ├── kind-config.yaml          # Standard kind cluster config
│   ├── kind-calico.yaml          # Kind config with default CNI disabled
│   └── calico.yaml               # Calico manifest for offline install
├── cheatsheets/
│   ├── kubectl-essentials.md     # Command reference
│   ├── ai-prompts.md             # Curated prompts for each week
│   └── yaml-quick-ref.md         # YAML templates for common objects
├── week-01/                      # Core Objects
│   ├── README.md
│   ├── exercises/                # 5 guided labs
│   └── manifests/broken/         # 5 broken manifests to debug
├── week-02/                      # Config, Storage, Networking
│   ├── README.md
│   ├── exercises/
│   └── manifests/broken/
├── week-03/                      # Security Hardening
│   ├── README.md
│   ├── exercises/
│   └── manifests/broken/
└── week-04/                      # Operations & Attack/Defend
    ├── README.md
    ├── exercises/
    └── manifests/broken/
```

## What's Next After 4 Weeks

This plan covers core K8s and security hardening. Natural follow-ups:

- **CKA exam prep** — extend into a 13-week plan covering all exam domains
- **CKS (Certified Kubernetes Security Specialist)** — Week 3 here is a direct on-ramp
- **Helm chart authoring** — Week 4 introduces Helm; go deeper with custom charts
- **GitOps with Flux or ArgoCD** — add a local GitOps workflow to the kind cluster
