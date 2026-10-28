#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== Installing Docker ==="

if command -v docker &>/dev/null; then
    echo "Docker already installed: $(docker --version)"
else
    sudo apt update
    sudo apt install -y docker.io
    sudo systemctl enable --now docker
fi

if ! groups "$USER" | grep -q docker; then
    echo "Adding $USER to docker group (re-login required after this script)..."
    sudo usermod -aG docker "$USER"
    echo "NOTE: Log out and back in, then re-run this script to continue."
    exit 0
fi

echo ""
echo "=== Installing kubectl ==="

if command -v kubectl &>/dev/null; then
    echo "kubectl already installed: $(kubectl version --client --short 2>/dev/null || kubectl version --client)"
else
    KUBECTL_VERSION=$(curl -L -s https://dl.k8s.io/release/stable.txt)
    curl -LO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl"
    sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
    rm -f kubectl
    echo "kubectl ${KUBECTL_VERSION} installed"
fi

echo ""
echo "=== Installing kind ==="

if command -v kind &>/dev/null; then
    echo "kind already installed: $(kind version)"
else
    curl -Lo kind https://kind.sigs.k8s.io/dl/latest/kind-linux-amd64
    sudo install -o root -g root -m 0755 kind /usr/local/bin/kind
    rm -f kind
    echo "kind installed"
fi

echo ""
echo "=== Creating kind cluster ==="

if kind get clusters 2>/dev/null | grep -q "^lab$"; then
    echo "Cluster 'lab' already exists"
else
    kind create cluster --name lab --config "$SCRIPT_DIR/kind-config.yaml"
fi

echo ""
echo "=== Verifying cluster ==="
kubectl cluster-info
kubectl get nodes

echo ""
echo "=== Cluster setup complete ==="
echo "Cluster name: lab"
echo "Reset anytime: ./setup/reset-cluster.sh"
