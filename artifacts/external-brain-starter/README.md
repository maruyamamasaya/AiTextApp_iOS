# AiTextApp 外部ブレイン・スターター

このフォルダの中身を、外部ブレインとして使うGitHubリポジトリのルートへ配置してください。

## 最初の設定

- AIペルソナの `AGENT.md` パス: `personas/default/AGENT.md`
- 外部ブレイン: ON
- 最大取得件数: まずは `3`
- GitHub Repository／Branch／Tokenを保存したあと、「接続を確認」→「今すぐ同期」の順で実行

## 動作確認

AIへの依頼例:

> 外部ブレインの接続状態を判断するとき、何を確認するべき？

送信前プレビューで次を確認します。

- `AGENT.md`: `personas/default/AGENT.md`
- `取得資料`: 1件以上
- 取得資料に `projects/aitextapp/knowledge/external-brain-operation.md` が含まれる
- 最終payloadに資料本文が含まれる

取得資料が0件でも、GitHub接続失敗とは限りません。質問と資料のキーワードが一致しなかった状態です。

## 文書作成ルール

1. 冒頭へYAML front matterを置く。
2. 正式な知識は `status: active` にする。
3. `status: draft` または `type: draft` は通常検索から除外される。
4. `#` と `##` で、1見出しにつき1テーマに分ける。
5. 固有名詞、判断、条件、エラー文など、検索に使いそうな語を本文にも書く。
6. 事実、判断、未確認事項を混ぜない。
7. knowledgeは後から再利用できる知識単位でファイルを分ける。journalは1日または1つの出来事を目安に、その時の視点を保って記録する。

## 推奨ディレクトリ

```text
personas/
  default/
    AGENT.md
projects/
  aitextapp/
    knowledge/
      project-overview.md
      external-brain-operation.md
      user-profile.md
shared/
  preferences/
    communication.md
```

`user-profile.md` は後から項目を埋めるための簡易プロフィールです。GitHubへpushしたあとは、AiTextAppで「今すぐ同期」を実行してください。

`type: journal`の日記は、Human Thought／Daily Summaryなら自分の記録、AI Thoughtなら生成元AIペルソナの記録として作れます。AIは検索時に、日記を現在の指示ではなく過去を思い出すための参考として扱います。

## 日記のテンプレート

```markdown
---
title: その日の短いタイトル
type: journal
project: aitextapp
tags:
  - 日記
status: active
updated: YYYY-MM-DD
---

# 日記

## 出来事

- 起きたことを書く。

## 感じたこと・考えたこと

- その時の気持ちや考えを書く。

## 覚えておきたいこと

- 後で思い出したいことを書く。

## 未確認

- 当時まだ分からなかったことを書く。
```

## 新しいKnowledgeのテンプレート

```markdown
---
title: 短く具体的なタイトル
type: knowledge
project: aitextapp
tags:
  - 検索キーワード
  - 関連語
status: active
priority: normal
updated: YYYY-MM-DD
---

# 結論

- 最も再利用したい事実や判断を書く。

## 条件

- いつ適用されるかを書く。

## 根拠

- 判断理由や確認元を書く。

## 未確認

- まだ確定していないことを書く。
```
