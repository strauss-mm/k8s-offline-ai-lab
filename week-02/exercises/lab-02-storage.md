# Lab 02: PersistentVolumes and PersistentVolumeClaims

## Objective

Create PersistentVolumes and PersistentVolumeClaims, bind them, use them in Pods, and prove data persists across Pod deletion.

## Setup

```bash
kubectl create namespace week2-lab02
kubectl config set-context --current --namespace=week2-lab02
```

---

## Exercise 1: Create a PersistentVolume

Create a PV named `local-pv` with:
- Capacity: 1Gi
- Access mode: ReadWriteOnce
- hostPath: /data/pv-lab
- Reclaim policy: Retain

<details>
<summary>Solution</summary>

First, create the directory on the kind node:
```bash
docker exec kind-control-plane mkdir -p /data/pv-lab
```

Apply `manifests/pv.yaml`:
```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: local-pv
spec:
  capacity:
    storage: 1Gi
  accessModes:
  - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  hostPath:
    path: /data/pv-lab
    type: DirectoryOrCreate
```

```bash
kubectl apply -f manifests/pv.yaml
kubectl get pv
```

Status should be `Available`.
</details>

---

## Exercise 2: Create a PVC and Bind It

Create a PVC named `data-claim` requesting 500Mi with ReadWriteOnce access. Verify it binds to the PV.

<details>
<summary>Solution</summary>

Apply `manifests/pvc.yaml`:
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: data-claim
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 500Mi
```

```bash
kubectl apply -f manifests/pvc.yaml
kubectl get pvc
kubectl get pv
```

The PVC should show `Bound` and the PV should show `Bound` with the claim reference.

Key point: A PVC binds to a PV if:
1. Access modes match
2. PV capacity >= PVC request
3. StorageClass matches (empty matches empty)
</details>

---

## Exercise 3: Use the PVC in a Pod

Create a Pod that mounts the PVC and writes a timestamped message to a file.

<details>
<summary>Solution</summary>

Apply `manifests/pod-with-pv.yaml`:
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: writer
spec:
  containers:
  - name: app
    image: busybox
    command:
    - sh
    - -c
    - |
      echo "Written at $(date) by pod $(hostname)" >> /data/messages.txt
      cat /data/messages.txt
      sleep 3600
    volumeMounts:
    - name: storage
      mountPath: /data
  volumes:
  - name: storage
    persistentVolumeClaim:
      claimName: data-claim
  restartPolicy: Never
```

```bash
kubectl apply -f manifests/pod-with-pv.yaml
kubectl logs writer
```

You should see the timestamped message.
</details>

---

## Exercise 4: Prove Data Persistence

Delete the Pod, create a new one that mounts the same PVC, and verify the data is still there.

<details>
<summary>Solution</summary>

```bash
kubectl delete pod writer
```

Create a reader Pod:
```bash
kubectl run reader --image=busybox --restart=Never \
  --overrides='{
    "spec": {
      "containers": [{
        "name": "reader",
        "image": "busybox",
        "command": ["cat", "/data/messages.txt"],
        "volumeMounts": [{"name": "storage", "mountPath": "/data"}]
      }],
      "volumes": [{
        "name": "storage",
        "persistentVolumeClaim": {"claimName": "data-claim"}
      }]
    }
  }'
```

```bash
kubectl logs reader
```

The original message is still there. The data lives on the PV, not in the Pod.
</details>

---

## Exercise 5: Understand Access Modes and Reclaim Policies

Answer these, then verify with `kubectl explain`:

1. What are the three access modes? When would you use each?
2. What happens with `Retain` vs `Delete` vs `Recycle` reclaim policies?
3. Can two Pods in the same node use a ReadWriteOnce PV simultaneously?

<details>
<summary>Answers</summary>

**Access Modes:**
- `ReadWriteOnce (RWO)` — mounted read-write by a single node. Most common for single-Pod workloads.
- `ReadOnlyMany (ROX)` — mounted read-only by many nodes. Good for shared config/data.
- `ReadWriteMany (RWX)` — mounted read-write by many nodes. Requires a network filesystem (NFS, CephFS). hostPath does NOT support this.

**Reclaim Policies:**
- `Retain` — PV is kept after PVC deletion. Data preserved, manual cleanup needed. PV enters `Released` state (won't rebind automatically).
- `Delete` — PV and its data are deleted when PVC is deleted. Common with dynamic provisioning.
- `Recycle` — deprecated. Was a basic `rm -rf` on the volume.

**RWO clarification:** RWO means one *node*, not one Pod. Two Pods on the same node CAN use the same RWO PV. Two Pods on different nodes cannot.

Verify:
```bash
kubectl explain pv.spec.accessModes
kubectl explain pv.spec.persistentVolumeReclaimPolicy
```
</details>

---

## Exercise 6: What Happens When You Delete the PVC?

Delete the PVC while no Pod is using it. Observe the PV state.

<details>
<summary>Solution</summary>

```bash
kubectl delete pod reader
kubectl delete pvc data-claim
kubectl get pv local-pv
```

With `Retain` policy, the PV status changes to `Released`. It will NOT automatically bind to a new PVC. The data is still on disk.

To reuse it, you'd need to:
1. Remove the `claimRef` from the PV: `kubectl patch pv local-pv -p '{"spec":{"claimRef": null}}'`
2. Create a new PVC

Or verify the data is still on the node:
```bash
docker exec kind-control-plane cat /data/pv-lab/messages.txt
```
</details>

---

## Verification Checklist

- [ ] Created a PersistentVolume with hostPath
- [ ] Created a PVC that bound to the PV
- [ ] Mounted the PVC in a Pod and wrote data
- [ ] Deleted the Pod and proved data persisted
- [ ] Understood access modes (RWO, ROX, RWX)
- [ ] Observed PV behavior after PVC deletion with Retain policy

## Cleanup

```bash
kubectl delete namespace week2-lab02
kubectl delete pv local-pv
docker exec kind-control-plane rm -rf /data/pv-lab
kubectl config set-context --current --namespace=default
```
