# kubectl Essentials

## Aliases (add to ~/.bashrc)

```bash
alias k=kubectl
alias kgp='kubectl get pods'
alias kgs='kubectl get svc'
alias kgd='kubectl get deploy'
alias kgn='kubectl get nodes'
alias kaf='kubectl apply -f'
alias kdf='kubectl delete -f'
export do='--dry-run=client -o yaml'
```

With aliases: `k run nginx --image=nginx:1.27 $do > pod.yaml`

## Core Commands

```bash
# List resources
kubectl get pods                          # Pods in current namespace
kubectl get pods -A                       # All namespaces
kubectl get pods -o wide                  # Show node and IP
kubectl get pods -l app=web               # Filter by label
kubectl get all                           # Pods, Services, Deployments, etc.

# Inspect
kubectl describe pod <name>               # Events, conditions, containers
kubectl logs <pod>                        # Container stdout
kubectl logs <pod> -c <container>         # Specific container in multi-container pod
kubectl logs <pod> --previous             # Previous (crashed) container
kubectl logs <pod> -f                     # Follow/stream logs

# Interactive
kubectl exec -it <pod> -- /bin/sh         # Shell into a pod
kubectl exec <pod> -- cat /etc/hosts      # Run a single command
kubectl port-forward svc/<name> 8080:80   # Forward local port to service

# Create from CLI
kubectl run nginx --image=nginx:1.27                          # Create a pod
kubectl create deployment web --image=nginx:1.27 --replicas=3 # Create deployment
kubectl expose deployment web --port=80 --type=NodePort       # Create service

# Generate YAML (don't apply, just output)
kubectl run nginx --image=nginx:1.27 --dry-run=client -o yaml
kubectl create deployment web --image=nginx:1.27 --dry-run=client -o yaml
kubectl create service clusterip my-svc --tcp=80:80 --dry-run=client -o yaml

# Apply and delete
kubectl apply -f manifest.yaml
kubectl delete -f manifest.yaml
kubectl delete pod <name>
kubectl delete pod <name> --force --grace-period=0   # Instant kill (testing only)

# Edit live
kubectl edit deployment <name>            # Opens in $EDITOR
kubectl scale deployment <name> --replicas=5
kubectl set image deployment/<name> nginx=nginx:1.28
```

## Built-in Docs (works offline)

```bash
kubectl explain pod
kubectl explain pod.spec
kubectl explain pod.spec.containers
kubectl explain pod.spec.containers.resources
kubectl explain deployment.spec.strategy
kubectl explain service.spec.type
kubectl explain networkpolicy.spec

# Recursive — shows all fields
kubectl explain pod.spec --recursive | head -50
```

## Namespaces

```bash
kubectl get ns
kubectl create ns dev
kubectl get pods -n dev
kubectl config set-context --current --namespace=dev   # Switch default namespace
```

## Labels and Selectors

```bash
kubectl label pod <name> env=prod
kubectl label pod <name> env-                          # Remove label
kubectl get pods --show-labels
kubectl get pods -l env=prod
kubectl get pods -l 'env in (prod,staging)'
kubectl get pods -l env!=dev
```

## JSONPath Output

```bash
# Get pod IPs
kubectl get pods -o jsonpath='{.items[*].status.podIP}'

# Get node names
kubectl get nodes -o jsonpath='{.items[*].metadata.name}'

# Get container images
kubectl get pods -o jsonpath='{.items[*].spec.containers[*].image}'

# Custom columns
kubectl get pods -o custom-columns='NAME:.metadata.name,STATUS:.status.phase,IP:.status.podIP'

# Sort by restart count
kubectl get pods --sort-by='.status.containerStatuses[0].restartCount'
```

## Debugging

```bash
# Why is a pod stuck?
kubectl describe pod <name>               # Check Events section at the bottom
kubectl get events --sort-by=.lastTimestamp

# Quick debug pod
kubectl run debug --image=busybox -it --rm -- sh
kubectl run debug --image=busybox -it --rm -- nslookup my-service
kubectl run debug --image=busybox -it --rm -- wget -qO- http://my-service:80

# Check RBAC
kubectl auth can-i create pods
kubectl auth can-i list secrets --as=system:serviceaccount:default:my-sa

# Resource usage
kubectl top nodes
kubectl top pods
```

## Rollouts

```bash
kubectl rollout status deployment/<name>
kubectl rollout history deployment/<name>
kubectl rollout undo deployment/<name>
kubectl rollout undo deployment/<name> --to-revision=2
kubectl rollout restart deployment/<name>
```
