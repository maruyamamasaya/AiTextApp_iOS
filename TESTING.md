# Testing

## Test Strategy

UI非依存のドメイン／永続化／ExportはSwift PackageとしてLinux/macOS共通で検証します。SwiftUI appとXCUITestはmacOS/XcodeのSimulatorで検証します。

## Unit / Persistence Test

```bash
swift test
```

入力境界、Unicode、SQLite順序、soft delete、再読込、2世代backup、JSON migration、Markdown／JSON Export、Continuation、分岐Historyに加え、Reviewの日境界・7日範囲・安定昇順・削除除外・Continuation件数を検証します。

## UI Test

`AiTextAppUITests`は空投稿不可、投稿後入力クリア、Timeline表示、削除確認に加え、DetailからのContinuation作成、History表示、History Reviewの古い順表示・件数・Detail遷移、Timeline反映をidentifierベースで検証します。

```bash
xcodebuild -project AiTextApp.xcodeproj -scheme AiTextApp \
  -destination 'platform=iOS Simulator,name=iPhone SE (3rd generation)' test
```

キーボード表示、140文字、複数件、Dynamic Type、Light/Dark mode、VoiceOver label、Share Sheet保存先はSimulator／実機で手動確認します。

## Build

```bash
xcodebuild -project AiTextApp.xcodeproj -scheme AiTextApp \
  -destination 'platform=iOS Simulator,name=iPhone SE (3rd generation)' build
```

最新標準iPhone名は`xcrun simctl list devices available`で確認してdestinationへ指定します。

## General Checks

```bash
git diff --check
git status --short
git ls-files
```
