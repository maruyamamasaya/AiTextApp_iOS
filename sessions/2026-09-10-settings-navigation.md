# 設定導線の再整理

## 依頼

消えたように見える設定機能を、Timelineトップの歯車から開けるようにする。

## 対応

- Timeline右上へ設定ボタンを追加した。
- プロフィール／AI Persona、Markdown／JSON Export、外部バックアップを設定画面へ集約した。
- 個別機能の既存処理とaccessibility identifierは維持した。

## 検証

- `swift test`: 69件成功。
- iOS Simulator向けDebug build: 成功。
