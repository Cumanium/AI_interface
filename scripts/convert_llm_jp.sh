#!/usr/bin/env bash
# LLM-jp-3 150M instruct3 を MLX 形式（4bit）に変換して同梱用フォルダに置く（Apple Silicon の Mac で実行）。
#
# 事前準備: pip install -U mlx-lm
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$ROOT/App/Resources/Models/llm-jp-3-150m-instruct3-4bit"

if [ -e "$DEST" ]; then
  echo "既にあります: $DEST（作り直す場合は削除してから実行）" >&2
  exit 1
fi

mlx_lm.convert --hf-path llm-jp/llm-jp-3-150m-instruct3 --mlx-path "$DEST" -q --q-bits 4
du -sh "$DEST"
