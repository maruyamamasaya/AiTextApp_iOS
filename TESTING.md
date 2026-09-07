# Testing

## Test Strategy

現時点ではソースコード、Xcode project、テスト、検証スクリプトがなく、実行可能なアプリ検証はありません。実装開始時に、ローカルとCIで同じコマンドを実行できるよう本書を更新します。存在しないコマンドを推測で掲載しません。

## 現在利用できるチェック

```bash
git status --short
git diff --check
git ls-files
```

Markdown文書の変更では、リンク先の存在確認、機密らしい値がないことの確認、`git diff --check`を行います。

## Lint

未導入です。SwiftLintなどの採用は未決定です。

## Typecheck

専用コマンドは未導入です。Swift/Xcodeプロジェクトも未登録です。

## Unit Test

テストターゲットおよびテストコードはありません。

## Integration Test

ありません。

## E2E / UI Test

ありません。

## Build

Xcode project/workspace、scheme、Swift Packageがないため実行できません。

## 変更内容 → 実行する検証（導入後の更新指針）

| 変更 | 最低限の検証 |
| --- | --- |
| 文書のみ | リンク確認 + `git diff --check` |
| UI | lint（導入済みなら）+ 関連unit/UI test + 対象schemeのbuild |
| ドメインロジック | 関連unit test + typecheck/build |
| API・永続化 | unit test + 関連integration test + build |
| project/依存/全体構成 | lint + 全test + clean build |

実際のtarget、scheme、destinationが追加されたら、表の一般名をコピー可能な正確なコマンドへ置き換えてください。
