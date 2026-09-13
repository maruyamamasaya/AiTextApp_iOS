---
title: 外部ブレインの接続・同期・検索の判断
type: knowledge
project: aitextapp
tags:
  - 外部ブレイン
  - GitHub
  - 接続
  - 同期
  - AGENT.md
  - Retrieval
  - 取得資料
status: active
priority: high
updated: 2026-09-12
---

# 結論

- 外部ブレインは「GitHub接続」「ローカル同期」「AGENT.md読込」「検索」「prompt投入」の段階に分けて判断する。
- AIが「接続できない」と発言しても、それだけでは接続失敗の証拠にならない。
- 最終的な利用有無は、送信前プレビューの取得資料件数と最終payloadで確認する。

## GitHub接続

- RepositoryとBranchの読取り成功は、GitHubへ到達できたことを示す。
- GitHub接続成功だけでは、KnowledgeがAIへ渡ったことを示さない。

## 同期

- 「今すぐ同期」でGitHub上のMarkdownを端末のローカルキャッシュへ取り込む。
- Persona用AGENT.mdが同期されていない場合、そのPersonaは外部ブレインを利用できない。
- 前回キャッシュを利用している場合、GitHubの最新版と一致しているとは限らない。

## 検索

- `取得資料: 1件以上` は、検索結果がAIのpromptへ投入されたことを示す。
- `取得資料: 0件` は、AGENT.mdは読めたが今回の検索語に一致する資料がなかった状態。
- `利用なし` は、設定OFF、AGENT.md欠落・不正、キャッシュまたは検索処理の失敗を含む可能性がある。

## 切り分け手順

1. 外部ブレイン設定でGitHub接続を確認する。
2. 「今すぐ同期」を実行する。
3. PersonaプロフィールでAGENT.mdのパスを確認する。
4. 送信前プレビューで取得資料件数を見る。
5. 1件以上なら、最終payloadに資料本文が含まれることを確認する。
6. 資料が入っているのにAIが接続不能と答えた場合は、接続障害ではなくAIの誤回答として扱う。

## 検索用キーワード

- GitHub接続、Repository Read、Branch Read、同期、ローカルキャッシュ
- AGENT.md、Retrieval Route、取得資料、最終payload、外部ブレイン
- 接続できない、利用なし、検索結果0件、参照資料なし
