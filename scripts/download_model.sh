#!/usr/bin/env bash
# アプリに同梱するモデルを App/Resources/Models/ に取得する（Mac で実行）。
#
# 使い方:
#   ./scripts/download_model.sh                                  # 第一候補 Qwen3 0.6B
#   ./scripts/download_model.sh mlx-community/Qwen3-1.7B-4bit    # 別のモデル
#
# 事前準備: pip install -U "huggingface_hub[cli]"   （`hf` コマンドが入る）
set -euo pipefail

MODEL_ID="${1:-mlx-community/Qwen3-0.6B-4bit}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$ROOT/App/Resources/Models/${MODEL_ID##*/}"

if ! command -v hf >/dev/null 2>&1; then
  echo "hf コマンドが見つかりません。pip install -U \"huggingface_hub[cli]\" を実行してください。" >&2
  exit 1
fi

mkdir -p "$DEST"
hf download "$MODEL_ID" \
  --local-dir "$DEST" \
  --include "*.json" "*.safetensors" "*.jinja" "*.txt" "tokenizer*"

echo "保存先: $DEST"
du -sh "$DEST"
