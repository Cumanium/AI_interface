# 同梱モデルの置き場所

ここに置いたフォルダは、アプリのバンドルに `Models/` としてコピーされます。
同梱したモデルは、ネットワークがなくても（機内モードでも）読み込めます。

```
App/Resources/Models/
└── Qwen3-0.6B-4bit/        ← scripts/download_model.sh で取得
    ├── config.json
    ├── model.safetensors
    ├── tokenizer.json
    └── tokenizer_config.json …
```

モデル本体は数百 MB あるため、git では管理しません（`.gitignore` 済み）。
