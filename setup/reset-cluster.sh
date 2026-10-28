#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLUSTER_NAME="lab"
USE_CALICO=false

if [[ "${1:-}" == "--calico" ]]; then
    USE_CALICO=true
    echo "=== Resetting cluster with Calico CNI (for NetworkPolicy labs) ==="
else
    echo "=== Resetting cluster with default CNI ==="
fi

# Delete existing cluster
if kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
    echo "Deleting existing cluster '$CLUSTER_NAME'..."
    kind delete cluster --name "$CLUSTER_NAME"
fi

# Create new cluster
if $USE_CALICO; then
    echo "Creating cluster with Calico CNI..."
    kind create cluster --name "$CLUSTER_NAME" --config "$SCRIPT_DIR/kind-calico.yaml"

    echo "Installing Calico..."
    kubectl apply -f "$SCRIPT_DIR/calico.yaml"

    echo "Waiting for Calico to be ready..."
    kubectl -n kube-system wait --for=condition=Ready pod -l k8s-app=calico-node --timeout=120s 2>/dev/null || \
        echo "Calico pods still starting — check with: kubectl -n kube-system get pods"
else
    kind create cluster --name "$CLUSTER_NAME" --config "$SCRIPT_DIR/kind-config.yaml"
fi

# Reload pre-pulled images
echo ""
echo "Loading pre-pulled images into cluster..."
for img in nginx:1.27 busybox redis:7 httpd:2.4 python:3.12-slim; do
    docker image inspect "$img" &>/dev/null && kind load docker-image "$img" --name "$CLUSTER_NAME" 2>/dev/null || true
done

if $USE_CALICO; then
    for img in calico/cni:v3.28.0 calico/node:v3.28.0 calico/kube-controllers:v3.28.0; do
        docker image inspect "docker.io/$img" &>/dev/null && kind load docker-image "docker.io/$img" --name "$CLUSTER_NAME" 2>/dev/null || true
    done
fi

echo ""
echo "=== Cluster ready ==="
kubectl get nodes
echo ""
echo "Tip: Run 'kubectl get pods -A' to verify all system pods are running."
