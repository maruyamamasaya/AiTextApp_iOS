---
title: AiTextApp プロジェクト概要
type: knowledge
project: aitextapp
tags:
  - AiTextApp
  - Thought
  - iOS
  - SwiftUI
  - SQLite
status: active
priority: high
updated: 2026-09-12
---

# プロダクト

- AiTextAppは、短いThoughtを端末内に記録して振り返るiPhone向けアプリ。
- 主な画面はHome、Mentions、AI機能、Insights、Profile。
- Thought本文の上限は140文字。

## データ

- Thoughtの正本は端末内のSQLite。
- 削除はsoft deleteとして扱う。
- 外部ブレインの同期キャッシュは再生成可能な派生データであり、Thoughtの正本ではない。

## 外部ブレイン

- GitHub上のMarkdownを端末へ同期する。
- AIはGitHubへ直接アクセスせず、端末が検索してpromptへ入れた資料だけを参照する。
- AIの返答内容だけでは、GitHub接続の成否を判断しない。

## 未確認

- 実機で現在使用しているGitHub Repository、Branch、Token権限は、この文書では確定しない。
