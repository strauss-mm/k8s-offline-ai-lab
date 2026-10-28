# Lab 01: ConfigMaps and Secrets

## Objective

Create ConfigMaps and Secrets using multiple methods, then consume them in Pods as environment variables and mounted volumes.

## Setup

```bash
kubectl create namespace week2-lab01
kubectl config set-context --current --namespace=week2-lab01
```

---

## Exercise 1: ConfigMap from Literal Values

Create a ConfigMap named `app-config` with:
- `APP_ENV=production`
- `LOG_LEVEL=info`
- `MAX_CONNECTIONS=100`

Then create a Pod that reads these as environment variables and prints them.

<details>
<summary>Solution</summary>

```bash
kubectl create configmap app-config \
  --from-literal=APP_ENV=production \
  --from-literal=LOG_LEVEL=info \
  --from-literal=MAX_CONNECTIONS=100
```

Verify:
```bash
kubectl describe configmap app-config
```

Apply the Pod manifest `manifests/pod-configmap-env.yaml`:
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: env-reader
spec:
  containers:
  - name: app
    image: busybox
    command: ["sh", "-c", "env | grep -E 'APP_ENV|LOG_LEVEL|MAX_CONNECTIONS' && sleep 3600"]
    envFrom:
    - configMapRef:
        name: app-config
  restartPolicy: Never
```

```bash
kubectl apply -f manifests/pod-configmap-env.yaml
kubectl logs env-reader
```

Expected output:
```
APP_ENV=production
LOG_LEVEL=info
MAX_CONNECTIONS=100
```
</details>

---

## Exercise 2: ConfigMap from a File

Create a file called `nginx.conf` with custom config, then create a ConfigMap from it and mount it as a volume.

<details>
<summary>Solution</summary>

Create the config file:
```bash
cat > /tmp/nginx.conf <<'EOF'
server {
    listen 80;
    server_name localhost;
    location / {
        return 200 'Hello from ConfigMap!\n';
        add_header Content-Type text/plain;
    }
}
EOF
```

Create the ConfigMap:
```bash
kubectl create configmap nginx-config --from-file=/tmp/nginx.conf
```

Apply `manifests/pod-configmap-volume.yaml`:
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx-custom
spec:
  containers:
  - name: nginx
    image: nginx:1.27
    volumeMounts:
    - name: config-vol
      mountPath: /etc/nginx/conf.d
  volumes:
  - name: config-vol
    configMap:
      name: nginx-config
  restartPolicy: Never
```

```bash
kubectl apply -f manifests/pod-configmap-volume.yaml
kubectl exec nginx-custom -- cat /etc/nginx/conf.d/nginx.conf
kubectl exec nginx-custom -- curl -s localhost
```
</details>

---

## Exercise 3: ConfigMap from a YAML Manifest

Create a ConfigMap using a YAML manifest (not imperative commands).

<details>
<summary>Solution</summary>

Apply `manifests/configmap-literal.yaml`:
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-settings
data:
  database_host: "db.internal.local"
  database_port: "5432"
  cache_ttl: "300"
```

```bash
kubectl apply -f manifests/configmap-literal.yaml
kubectl get configmap app-settings -o yaml
```
</details>

---

## Exercise 4: Create an Opaque Secret

Create a Secret with a username and password. Mount it as both environment variables and a volume. Verify the values are decoded inside the Pod.

<details>
<summary>Solution</summary>

Imperative:
```bash
kubectl create secret generic db-credentials \
  --from-literal=username=admin \
  --from-literal=password=s3cur3P@ss
```

Verify it's stored base64-encoded:
```bash
kubectl get secret db-credentials -o yaml
```
You'll see values like `dXNlcm5hbWU=` — that's base64.

Apply `manifests/pod-secret.yaml`:
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: secret-reader
spec:
  containers:
  - name: app
    image: busybox
    command:
    - sh
    - -c
    - |
      echo "=== From env vars ==="
      echo "DB_USER=$DB_USER"
      echo "DB_PASS=$DB_PASS"
      echo "=== From mounted files ==="
      echo "username: $(cat /etc/secrets/username)"
      echo "password: $(cat /etc/secrets/password)"
      sleep 3600
    env:
    - name: DB_USER
      valueFrom:
        secretKeyRef:
          name: db-credentials
          key: username
    - name: DB_PASS
      valueFrom:
        secretKeyRef:
          name: db-credentials
          key: password
    volumeMounts:
    - name: secret-vol
      mountPath: /etc/secrets
      readOnly: true
  volumes:
  - name: secret-vol
    secret:
      secretName: db-credentials
  restartPolicy: Never
```

```bash
kubectl apply -f manifests/pod-secret.yaml
kubectl logs secret-reader
```

Expected output:
```
=== From env vars ===
DB_USER=admin
DB_PASS=s3cur3P@ss
=== From mounted files ===
username: admin
password: s3cur3P@ss
```

The values are decoded for the Pod — Kubernetes handles the base64 decode automatically.
</details>

---

## Exercise 5: Declarative Secret from YAML

Create a Secret using a YAML manifest. Remember: values in `data:` must be base64-encoded; values in `stringData:` can be plain text.

<details>
<summary>Solution</summary>

Apply `manifests/secret-opaque.yaml`:
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: api-keys
type: Opaque
stringData:
  api_key: "abc123def456"
  api_secret: "mysecretvalue"
```

```bash
kubectl apply -f manifests/secret-opaque.yaml
kubectl get secret api-keys -o jsonpath='{.data.api_key}' | base64 -d
```

Output: `abc123def456`

Using `stringData` avoids manual base64 encoding — Kubernetes encodes it on creation.
</details>

---

## Verification Checklist

- [ ] Created a ConfigMap from literal values
- [ ] Created a ConfigMap from a file
- [ ] Mounted a ConfigMap as environment variables
- [ ] Mounted a ConfigMap as a volume
- [ ] Created a Secret imperatively
- [ ] Created a Secret declaratively with `stringData`
- [ ] Mounted a Secret as env vars and volume
- [ ] Confirmed Secrets are base64-encoded in the API but decoded in the Pod

## Cleanup

```bash
kubectl delete namespace week2-lab01
kubectl config set-context --current --namespace=default
```
