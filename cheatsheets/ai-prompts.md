# AI Prompts for Kubernetes Learning

Curated prompts to use with your local LLM (Ollama). Run with:
```bash
ollama run gemma4-k8s    # Fast, 16K context
ollama run llama3.1:8b   # Best explanations
```

Or paste into the prompt interactively.

## General Learning Prompts

```
Explain [concept] like I'm an experienced developer but new to Kubernetes. 
Use concrete examples, not abstract descriptions.

What are the 3 most common mistakes people make with [concept]?

I just learned about [concept A]. How does it relate to [concept B]?

Give me a mental model for understanding [concept].
```

## Week 1: Core Objects

```
Generate 5 broken Pod manifests for me to debug. Each should have exactly 
one error. Don't tell me what the errors are — I'll find them myself. 
Use only the nginx:1.27 and busybox images.

Quiz me on Kubernetes Pods. Ask me 5 questions, one at a time. 
Wait for my answer before giving the next question.

Explain the lifecycle of a Pod from creation to termination. 
What happens at each stage?

What's the difference between a Pod, a Deployment, and a ReplicaSet? 
When would I use each?

Give me a broken Deployment manifest that looks correct but won't 
do a rolling update properly. What's wrong with it?

I ran 'kubectl get pods' and see STATUS: CrashLoopBackOff. 
Walk me through how to diagnose this.

Explain ClusterIP vs NodePort vs LoadBalancer. 
When is each one the right choice?
```

## Week 2: Config, Storage, Networking

```
Create a ConfigMap exercise: give me a scenario where I need to 
mount config as both an environment variable AND a file. 
Include the Pod spec but with 3 intentional errors.

Explain the difference between ConfigMaps and Secrets. 
Are Secrets actually secure in Kubernetes? What are the risks?

Give me a PersistentVolume exercise: create a PV and PVC, 
then prove that data survives Pod deletion. 
Walk me through the steps without giving me the YAML.

What happens when a PVC requests more storage than any PV can provide?

Quiz me on Kubernetes Namespaces and ResourceQuotas — 5 questions.

I want to route traffic to two different services based on URL path. 
Explain how Ingress works and what components I need.

Give me a broken Ingress manifest to debug.
```

## Week 3: Security Hardening

```
I have a Kubernetes cluster. An attacker has a shell in one Pod. 
What can they access by default? List the attack paths.

Review this YAML for security best practices. 
Tell me every security issue you see:
[paste your YAML here]

Generate a NetworkPolicy exercise: I have 3 namespaces 
(frontend, backend, database). Write the requirements in English, 
and I'll write the NetworkPolicies myself.

Explain RBAC in Kubernetes: Roles, ClusterRoles, RoleBindings, 
ClusterRoleBindings. Give me a real-world analogy.

Give me 3 RBAC scenarios to implement:
1. A ServiceAccount that can only read Pods in one namespace
2. A user who can create Deployments but not delete them
3. A ServiceAccount that can only view logs

What are Pod Security Standards? Explain baseline vs restricted.
What specific fields do I need to set in a Pod spec to pass restricted?

Give me a Pod manifest with 5 security issues. 
I'll fix them all to pass the restricted Pod Security Standard.

Explain securityContext at the Pod level vs container level. 
What fields go where? Give examples of each.
```

## Week 4: Operations & Attack/Defend

```
Design a liveness and readiness probe exercise: 
give me an app that needs both, and explain why each is needed.

I want to auto-scale a Deployment based on CPU. 
Walk me through HPA setup step by step.

Explain PodDisruptionBudget. When would I need one? 
Give me a scenario where not having one causes an outage.

Give me a Helm chart exercise: I need to template a Deployment 
with configurable replicas, image, and resource limits. 
Walk me through the file structure.

Attack scenario: I have a privileged Pod. What can I do from inside it? 
Walk me through the container escape path.

Give me a security audit checklist for a Kubernetes cluster. 
What are the top 10 things to check?

I have a 3-tier app (web, API, Redis). Help me design:
- The Deployment for each tier
- NetworkPolicies so web talks to API, API talks to Redis, 
  but web cannot reach Redis directly
- RBAC so the API ServiceAccount can read Secrets but web cannot
Don't give me YAML — describe what I need and I'll write it.
```

## Troubleshooting Prompts (use anytime)

```
I got this error. What does it mean and how do I fix it?
[paste kubectl describe or kubectl logs output]

My Pod is stuck in Pending. What are the possible causes?

My Service isn't routing traffic to my Pods. 
Walk me through debugging this step by step.

I applied a NetworkPolicy and now nothing can reach my Pod. 
What's the most likely mistake?

My Deployment rollout is stuck. kubectl rollout status shows 
it's waiting. What should I check?
```

## Review and Quiz Prompts

```
I just finished a lab on [topic]. Quiz me to check my understanding. 
Start with easy questions and get harder.

Review this manifest I wrote. Is it correct? 
Are there any best practices I'm missing?
[paste YAML]

Give me a rapid-fire round: 10 true-or-false questions about [topic]. 
I'll answer all 10, then you grade me.

Explain the output of this command. What is each column?
[paste kubectl get output]

I'm confused about [concept]. Explain it a different way.
```
