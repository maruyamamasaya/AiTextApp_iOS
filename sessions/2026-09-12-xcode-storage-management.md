# Session: Xcodeのストレージ管理ルール

- Date: 2026-09-12

## Request

iOS／macOSプロジェクト検証時のMacストレージ消費を抑える運用ルールを`AGENTS.md`へ追加する。

## Investigation

- Git rootが`AiTextApp`リポジトリであることを確認した。
- `CURRENT.md`と既存の`AGENTS.md`を確認した。
- `AGENTS.md`と`TESTING.md`に、`XCTestDevices`の事前記録・タスク単位のクリーンアップを含む同等の規定がないことを確認した。

## Changes

- ビルドで十分な場合はテストを省略する判断基準を追加した。
- テスト時のSimulator台数、並列実行、実行回数、ランタイム作成に関する制約を追加した。
- `XCTestDevices`の事前記録、安全なクリーンアップ、実行中プロセスの保護、最終報告を追加した。
- DerivedDataなど、ほかのXcodeデータを削除する前の確認を必須化した。

## Files Changed

- `AGENTS.md`
- `sessions/2026-09-12-xcode-storage-management.md`

## Validation

- 文書差分を確認した。
- コード変更ではないため、ビルドとテストは実行していない。

## Result

完了。

## Remaining Issues

なし。
