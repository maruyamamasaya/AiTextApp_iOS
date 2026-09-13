# 2026-09-12 外部ブレイン・スターターパッケージ

## 目的

AiTextAppの現行External Brain parser／retrieval実装へ適合し、GitHubリポジトリへそのまま配置できる最小Markdown構成を用意する。

## 作成内容

- `personas/default/AGENT.md`: 実装が要求するRole、Retrieval Route、Retrieval Rules。
- `projects/aitextapp/knowledge/`: プロジェクト概要と接続・同期・検索の切り分け資料。
- `projects/aitextapp/knowledge/user-profile.md`: 後から安全に追記できる簡易プロフィール。
- `shared/preferences/`: 日本語回答と事実・推測の区別に関する共通設定。
- `README.md`: GitHubへの配置、アプリ設定、動作確認、Knowledgeテンプレート。
- 配布用ZIP: `artifacts/aitextapp-external-brain-starter.zip`。

## 判断

- 見出しとfront matterは検索・保守に有効だが、それだけでは接続確認にならない。
- AIに接続状態を自己申告させず、アプリの接続確認、同期状態、取得資料件数、最終payloadを根拠にする。
- `status: active`を正式Knowledgeに使用し、`status: draft`は通常retrievalから除外する現行仕様に合わせた。
