#!/usr/bin/env bash
set -euo pipefail

CLUSTER_NAME="${1:-lab}"

echo "=== Pre-pulling images for offline use ==="
echo "Target cluster: $CLUSTER_NAME"

# Lab workload images
LAB_IMAGES=(
    "nginx:1.27"
    "busybox:latest"
    "redis:7"
    "httpd:2.4"
    "python:3.12-slim"
)

# Calico CNI (Week 3 — NetworkPolicy enforcement)
CALICO_IMAGES=(
    "docker.io/calico/cni:v3.28.0"
    "docker.io/calico/node:v3.28.0"
    "docker.io/calico/kube-controllers:v3.28.0"
)

# Ingress NGINX (Week 2)
INGRESS_IMAGES=(
    "registry.k8s.io/ingress-nginx/controller:v1.11.1"
    "registry.k8s.io/ingress-nginx/kube-webhook-certgen:v1.4.1"
)

ALL_IMAGES=("${LAB_IMAGES[@]}" "${CALICO_IMAGES[@]}" "${INGRESS_IMAGES[@]}")

echo ""
echo "=== Pulling ${#ALL_IMAGES[@]} images ==="

for img in "${ALL_IMAGES[@]}"; do
    echo "Pulling: $img"
    docker pull "$img"
done

echo ""
echo "=== Loading images into kind cluster ==="

for img in "${ALL_IMAGES[@]}"; do
    echo "Loading: $img"
    kind load docker-image "$img" --name "$CLUSTER_NAME" 2>/dev/null || \
        echo "  (cluster not running — image cached in Docker for later)"
done

echo ""
echo "=== Done ==="
echo "Images cached locally and loaded into cluster '$CLUSTER_NAME'."
echo "These are available offline. The cluster can only run pre-loaded images."
echo ""
echo "To load into a new cluster later:"
echo "  kind load docker-image nginx:1.27 busybox redis:7 --name lab"
