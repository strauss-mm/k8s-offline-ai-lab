#!/usr/bin/env bash
set -euo pipefail

echo "=== Installing Ollama ==="

if command -v ollama &>/dev/null; then
    echo "Ollama already installed: $(ollama --version)"
else
    curl -fsSL https://ollama.com/install.sh | sh
fi

echo ""
echo "=== Starting Ollama service ==="
if ! pgrep -x ollama &>/dev/null; then
    ollama serve &
    sleep 3
fi

echo ""
echo "=== Pulling models (this takes a while on first run) ==="

echo "Pulling llama3.1:8b (~4.7 GB)..."
ollama pull llama3.1:8b

echo "Pulling qwen2.5-coder:7b (~4.4 GB)..."
ollama pull qwen2.5-coder:7b

echo "Pulling gemma4:e4b (~2.5 GB)..."
ollama pull gemma4:e4b

echo ""
echo "=== Creating gemma4-k8s with 16K context window ==="

MODELFILE=$(mktemp)
cat > "$MODELFILE" <<'EOF'
FROM gemma4:e4b
PARAMETER num_ctx 16384
EOF
ollama create gemma4-k8s -f "$MODELFILE"
rm -f "$MODELFILE"

echo ""
echo "=== Verifying models ==="
ollama list

echo ""
echo "=== Quick test ==="
ollama run gemma4-k8s "In one sentence, what is a Kubernetes Pod?" --nowordwrap 2>/dev/null || true

echo ""
echo "=== Ollama setup complete ==="
echo "Models available:"
echo "  ollama run llama3.1:8b         # Best for explanations"
echo "  ollama run qwen2.5-coder:7b    # Best for YAML review"
echo "  ollama run gemma4-k8s          # Fast, 16K context"
