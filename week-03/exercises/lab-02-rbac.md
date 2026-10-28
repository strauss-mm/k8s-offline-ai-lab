# Lab 02: RBAC (Role-Based Access Control)

## Objective

Configure fine-grained access control using ServiceAccounts, Roles, RoleBindings, ClusterRoles, and ClusterRoleBindings. Test permissions with `kubectl auth can-i`.

## Concepts

- **ServiceAccount**: identity for pods (or humans, in testing scenarios)
- **Role**: grants permissions within a single namespace
- **ClusterRole**: grants permissions cluster-wide or on cluster-scoped resources
- **RoleBinding**: binds a Role (or ClusterRole) to a subject in a namespace
- **ClusterRoleBinding**: binds a ClusterRole to a subject cluster-wide

## Setup

```bash
kubectl create namespace rbac-lab
kubectl config set-context --current --namespace=rbac-lab
```

## Exercise 1: Create a read-only ServiceAccount

Create a ServiceAccount that can only get, list, and watch Pods in the `rbac-lab` namespace.

### Step 1: Create the ServiceAccount

```bash
kubectl apply -f ../manifests/rbac-serviceaccount.yaml
```

Or imperatively:

```bash
kubectl create serviceaccount pod-reader -n rbac-lab
```

### Step 2: Create the Role

**Write this yourself.** The Role should:
- Be in namespace `rbac-lab`
- Allow verbs: get, list, watch
- On resource: pods
- API group: "" (core)

<details>
<summary>Solution</summary>

```bash
kubectl apply -f ../manifests/rbac-role-pod-reader.yaml
```

Or imperatively:
```bash
kubectl create role pod-reader --verb=get,list,watch --resource=pods -n rbac-lab
```

</details>

### Step 3: Create the RoleBinding

**Write this yourself.** Bind the `pod-reader` Role to the `pod-reader` ServiceAccount.

<details>
<summary>Solution</summary>

```bash
kubectl apply -f ../manifests/rbac-rolebinding.yaml
```

Or imperatively:
```bash
kubectl create rolebinding pod-reader-binding --role=pod-reader --serviceaccount=rbac-lab:pod-reader -n rbac-lab
```

</details>

### Step 4: Test permissions

```bash
# Should return "yes"
kubectl auth can-i get pods --as=system:serviceaccount:rbac-lab:pod-reader -n rbac-lab

# Should return "yes"
kubectl auth can-i list pods --as=system:serviceaccount:rbac-lab:pod-reader -n rbac-lab

# Should return "no"
kubectl auth can-i create pods --as=system:serviceaccount:rbac-lab:pod-reader -n rbac-lab

# Should return "no"
kubectl auth can-i delete pods --as=system:serviceaccount:rbac-lab:pod-reader -n rbac-lab

# Should return "no" (different resource)
kubectl auth can-i get secrets --as=system:serviceaccount:rbac-lab:pod-reader -n rbac-lab

# Should return "no" (different namespace)
kubectl auth can-i get pods --as=system:serviceaccount:rbac-lab:pod-reader -n default
```

## Exercise 2: List all permissions

Check what a ServiceAccount can do:

```bash
kubectl auth can-i --list --as=system:serviceaccount:rbac-lab:pod-reader -n rbac-lab
```

This shows every permission the account has, including defaults. Look for the `pods` line.

## Exercise 3: ClusterRole for cluster-wide read access

Create a ClusterRole that allows reading pods in ALL namespaces, and bind it to a new ServiceAccount.

### Step 1: Create the pieces

```bash
kubectl create serviceaccount cluster-viewer -n rbac-lab
kubectl apply -f ../manifests/rbac-clusterrole.yaml
kubectl apply -f ../manifests/rbac-clusterrolebinding.yaml
```

### Step 2: Test cross-namespace access

```bash
# Should return "yes" for any namespace
kubectl auth can-i get pods --as=system:serviceaccount:rbac-lab:cluster-viewer -n default
kubectl auth can-i get pods --as=system:serviceaccount:rbac-lab:cluster-viewer -n kube-system
kubectl auth can-i list pods --as=system:serviceaccount:rbac-lab:cluster-viewer -n rbac-lab

# Should still return "no" for write operations
kubectl auth can-i create pods --as=system:serviceaccount:rbac-lab:cluster-viewer -n default
kubectl auth can-i delete deployments --as=system:serviceaccount:rbac-lab:cluster-viewer -n default
```

## Exercise 4: Debug broken RBAC

Deploy a pod that uses the `pod-reader` ServiceAccount and try to list pods from inside it:

```bash
kubectl run rbac-test --image=busybox --restart=Never \
  --overrides='{"spec":{"serviceAccountName":"pod-reader"}}' \
  --command -- sleep 3600

# This uses the pod's mounted token
kubectl exec rbac-test -- wget -qO- \
  --header="Authorization: Bearer $(kubectl exec rbac-test -- cat /var/run/secrets/kubernetes.io/serviceaccount/token)" \
  https://kubernetes.default.svc/api/v1/namespaces/rbac-lab/pods \
  --no-check-certificate 2>&1 | head -5
```

The request should succeed (200 OK with pod list JSON).

Now try to list secrets (should get 403 Forbidden):

```bash
kubectl exec rbac-test -- wget -qO- \
  --header="Authorization: Bearer $(kubectl exec rbac-test -- cat /var/run/secrets/kubernetes.io/serviceaccount/token)" \
  https://kubernetes.default.svc/api/v1/namespaces/rbac-lab/secrets \
  --no-check-certificate 2>&1 | head -5
```

## Exercise 5: Common RBAC mistakes to practice

Try each of these and predict what happens before running:

1. **Wrong API group**: Create a Role for `deployments` but set apiGroups to `""` instead of `"apps"`. What error do you get?

2. **Missing verb**: Create a Role with only `get` and `list` but not `watch`. Can the ServiceAccount run `kubectl get pods -w`?

3. **RoleBinding vs ClusterRoleBinding**: Bind a ClusterRole with a RoleBinding (not ClusterRoleBinding). What scope does it have?

4. **Non-existent Role**: Create a RoleBinding that references a Role name that doesn't exist. Does it error on create, or on use?

<details>
<summary>Answers</summary>

1. The Role creates fine, but `kubectl auth can-i get deployments` returns "no" because deployments are in the `apps` API group, not core.

2. `kubectl get pods -w` will fail because the watch verb is missing. The `-w` flag requires the `watch` verb.

3. A RoleBinding that references a ClusterRole limits the ClusterRole's permissions to just that namespace. This is a valid and common pattern for granting namespace-scoped access using a reusable ClusterRole.

4. The RoleBinding creates fine (Kubernetes doesn't validate the reference at create time). But `auth can-i` returns "no" for all operations because the binding points to nothing.

</details>

## Cleanup

```bash
kubectl delete namespace rbac-lab
```

## Key takeaways

- Always use the principle of least privilege: grant only the verbs and resources needed
- `kubectl auth can-i --as=` is your best friend for testing RBAC
- A RoleBinding referencing a ClusterRole scopes the ClusterRole down to one namespace
- API groups matter: pods are in `""`, deployments in `"apps"`, ingresses in `"networking.k8s.io"`
- Kubernetes does not validate RoleBinding references at creation time
- ServiceAccounts are namespace-scoped; reference format is `system:serviceaccount:<namespace>:<name>`
