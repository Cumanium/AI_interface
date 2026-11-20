# AI Interface（短編作品用の小道具 AI チャット）

短編作品の演出用小道具として iPhone で動かす、AI チャットボットのアプリです。
ローカル LLM（第一候補: **Qwen3 0.6B 4bit**）を MLX Swift でオフライン実行します。
本番テイク用に、決めた台詞を「生成しているように」表示する**台本モード**も持っています。

- モデル選定の経緯: [docs/01_model_selection.md](docs/01_model_selection.md)
- **Xcode なしで使うウェブ版（台本モードのみ）:** [web/prop-chat.html](web/prop-chat.html)。ブラウザだけで動き、claude.ai のアーティファクトとして公開して iPhone で開ける。

## 機能

| 機能 | 内容 |
|------|------|
| 台本モード | 入力内容に関係なく、台本の台詞を順に返す。文字送りのリズムは毎回同じ（編集でつながる） |
| AI 生成モード | ローカル LLM が実際に返答する。人格（システムプロンプト）、温度、シード固定を設定できる |
| 隠し設定画面 | 画面上部の AI の名前を **3 回タップ**すると開く。演者や画面に操作 UI を見せない |
| テイク操作 | 「会話を消して台本の頭に戻す」、「次に話す台詞」の指定（途中のカットからの撮り直し） |
| ベンチマーク | 実機で 5 問を生成し、最初の文字が出るまでの時間、生成速度、ピークメモリ、返答の内容を確認する |
| 計測オーバーレイ | 画面の隅に計測値を表示する（撮影時はオフ） |

## 構成

```
project.yml                 XcodeGen の定義（Xcode プロジェクトはここから生成）
App/
  Sources/
    AIInterfaceApp.swift
    Engines/MLXEngine.swift   MLX Swift で LLM を動かすエンジン
    ViewModels/               チャット画面の状態
    Views/                    チャット・設定・ベンチマーク画面
    Settings/                 設定の保存（UserDefaults）
  Resources/Models/          同梱モデルの置き場所（git 管理外）
Packages/PropCore/           UI と MLX に依存しないロジック（台本、文字送り、設定、計測）
  Tests/                     Swift Testing のテスト（Linux でも実行可能）
scripts/
  download_model.sh          同梱用モデルの取得
  convert_llm_jp.sh          LLM-jp-3 150M を MLX 形式に変換（比較用）
```

返答を作る部分は `ChatEngine` プロトコルで抽象化しています。
`ScriptedEngine`（台本）と `MLXEngine`（ローカル LLM）を同じ画面から切り替えられます。

## 必要なもの

- Apple Silicon の Mac と **Xcode 26 以降**（mlx-swift-lm 3.x は Swift 6.2 が必要）
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)（`brew install xcodegen`）
- 撮影用の iPhone（**iOS 17 以降**）。MLX は Metal を使うため**シミュレータでは AI 生成モードは動きません**（台本モードは動きます）
- 同梱モデルの取得用に `hf` コマンド（`pip install -U "huggingface_hub[cli]"`）

## セットアップ（Mac）

1. 同梱するモデルを取得する（約 350MB）。

   ```bash
   ./scripts/download_model.sh
   ```

2. Xcode プロジェクトを生成して開く。

   ```bash
   xcodegen generate
   ```

   ```bash
   open AIInterface.xcodeproj
   ```

3. Xcode で次の操作をする。
   - **Signing & Capabilities** で自分のチームを選ぶ（`project.yml` の `DEVELOPMENT_TEAM` に書いてもよい）。
   - 初回ビルド時に、`MLXHuggingFace` のマクロについて「Trust & Enable」を求められたら許可する。
4. iPhone を接続して実行する。

モデルを同梱しなかった場合は、AI 生成モードの初回にモデルを Hugging Face からダウンロードします（ネットワークが必要です）。
撮影現場で確実に動かすため、**同梱をおすすめします**。

## 使い方（撮影時）

1. 名前を 3 回タップして設定画面を開き、「台本」欄に台詞を書く。
   台詞の区切りは `---` だけの行です。`#` で始まる行はメモとして無視されます。

   ```text
   # S12 研究室
   こんにちは。今日はどんなご用件でしょうか？
   ---
   少し考えさせてください。
   ……はい、わかりました。
   ```

2. 「台本モードの文字送り」で、考える時間や文字の速さを作品のテンポに合わせる。
3. テイクの頭で「会話を消して台本の頭に戻す」を押す。
4. 演者は何を入力してもよい。送信するたびに、台本の次の台詞が返る。

AI 生成モードを使う場合は、「今すぐ読み込む」を押して事前にモデルを読み込んでおくと、最初の返答が速くなります。

## テスト

`PropCore` のロジックは、Mac でも Linux でも次のコマンドでテストできます。

```bash
cd Packages/PropCore && swift test
```

## ほかのモデルを試す

設定画面の「モデル」で切り替えられます（定義は `Packages/PropCore/Sources/PropCore/ModelCatalog.swift`）。

| モデル | 同梱方法 |
|--------|----------|
| Qwen3 0.6B（第一候補） | `./scripts/download_model.sh` |
| Qwen3 1.7B | `./scripts/download_model.sh mlx-community/Qwen3-1.7B-4bit` |
| Gemma 3 1B | `./scripts/download_model.sh mlx-community/gemma-3-1b-it-qat-4bit` |
| LLM-jp-3 150M | `./scripts/convert_llm_jp.sh`（要 `pip install mlx-lm`、Apple Silicon の Mac） |

## ライセンス上の注意

- Qwen3: Apache 2.0
- Gemma 3: Gemma 利用規約
- LLM-jp-3: Apache 2.0

上映時のクレジット表記の要否は、各モデルのライセンスを確認してください。
