# Lab 02: Helm — Package and Deploy Applications

## Objective

Learn to install Helm, understand chart structure, author a chart from scratch, and manage releases with install/upgrade/rollback.

---

## Part 1: Install Helm

Download the binary while online and keep it for offline use:

```bash
curl -fsSL https://get.helm.sh/helm-v3.16.2-linux-amd64.tar.gz -o helm.tar.gz
tar xzf helm.tar.gz
sudo install linux-amd64/helm /usr/local/bin/helm
helm version
```

Helm 3 is client-only (no Tiller). It talks directly to the Kubernetes API server using your kubeconfig.

---

## Part 2: Helm Concepts

| Concept | Description |
|---------|-------------|
| **Chart** | A package of Kubernetes manifests + templates + metadata |
| **Release** | A deployed instance of a chart (you can install the same chart multiple times) |
| **values.yaml** | Default configuration values; overridden at install/upgrade time |
| **templates/** | Go-templated Kubernetes manifests that render using values |
| **Chart.yaml** | Metadata: name, version, description, appVersion |

A chart is a directory:

```
mychart/
  Chart.yaml
  values.yaml
  templates/
    deployment.yaml
    service.yaml
```

---

## Part 3: Create a Chart from Scratch

Do not use `helm create` (it generates too much boilerplate). Build it by hand to understand every piece.

### Step 1: Chart.yaml

```bash
mkdir -p mychart/templates
```

```yaml
# mychart/Chart.yaml
apiVersion: v2
name: mychart
description: A minimal Helm chart for learning
type: application
version: 0.1.0
appVersion: "1.27"
```

### Step 2: values.yaml

```yaml
# mychart/values.yaml
replicaCount: 2

image:
  repository: nginx
  tag: "1.27"

service:
  type: ClusterIP
  port: 80

containerPort: 80
```

### Step 3: Deployment Template

```yaml
# mychart/templates/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ .Release.Name }}-app
  labels:
    app: {{ .Release.Name }}
spec:
  replicas: {{ .Values.replicaCount }}
  selector:
    matchLabels:
      app: {{ .Release.Name }}
  template:
    metadata:
      labels:
        app: {{ .Release.Name }}
    spec:
      containers:
      - name: {{ .Chart.Name }}
        image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
        ports:
        - containerPort: {{ .Values.containerPort }}
```

### Step 4: Service Template

```yaml
# mychart/templates/service.yaml
apiVersion: v1
kind: Service
metadata:
  name: {{ .Release.Name }}-svc
spec:
  type: {{ .Values.service.type }}
  selector:
    app: {{ .Release.Name }}
  ports:
  - port: {{ .Values.service.port }}
    targetPort: {{ .Values.containerPort }}
```

The complete chart is also available in `manifests/helm-chart/mychart/`.

---

## Part 4: Render and Install

### Render Locally (no cluster needed)

```bash
helm template my-release mychart/
```

This outputs the rendered YAML without installing anything. Check that the values substituted correctly.

### Install

```bash
helm install my-release mychart/
```

Verify:

```bash
helm list
kubectl get deployment my-release-app
kubectl get service my-release-svc
kubectl get pods -l app=my-release
```

### Override Values at Install

```bash
helm install my-release-v2 mychart/ --set replicaCount=5
kubectl get pods -l app=my-release-v2
```

---

## Part 5: Upgrade and Rollback

### Upgrade

Change the replica count on an existing release:

```bash
helm upgrade my-release mychart/ --set replicaCount=4
```

Check the revision:

```bash
helm history my-release
kubectl get pods -l app=my-release
```

### Rollback

```bash
helm rollback my-release 1
helm history my-release
kubectl get pods -l app=my-release
```

Revision 1 was 2 replicas. After rollback, you should see 2 Pods again.

---

## Part 6: Useful Commands

```bash
# See what values are in effect
helm get values my-release

# See all rendered manifests of a release
helm get manifest my-release

# Dry run an install (validate without deploying)
helm install test-run mychart/ --dry-run

# Uninstall
helm uninstall my-release
helm uninstall my-release-v2
```

---

## Cleanup

```bash
helm uninstall my-release 2>/dev/null
helm uninstall my-release-v2 2>/dev/null
rm -rf mychart/   # if you created it in the working directory
```

## AI Exercises

Ask your local LLM:
- "Explain Go template syntax in Helm charts with examples of if/else and range"
- "What is the difference between .Release.Name, .Chart.Name, and .Values?"
- "Generate a Helm chart that deploys a Redis StatefulSet with a PVC"
- "What are Helm hooks and when would you use a pre-install hook?"

Always validate generated templates with `helm template` before applying.
