# Testing

## Test Strategy

UI非依存のドメイン／永続化／ExportはSwift PackageとしてLinux/macOS共通で検証します。SwiftUI appとXCUITestはmacOS/XcodeのSimulatorで検証します。

## Unit / Persistence Test

```bash
swift test
```

入力境界、Unicode、SQLite順序、soft delete、再読込、内部2世代backup、JSON migration、Markdown／JSON Export、Continuation、分岐History、Review、AI要約promptの送信項目、Mock生成、再要約と原文分離保存に加え、外部backupの初回作成・2世代rotation・失敗時latest維持・manifest／integrity・不正manifest／破損SQLite拒否・完全Restore・Thought／Relation／soft delete History／schema保持を検証します。

## UI Test

`AiTextAppUITests`は空投稿不可、投稿後入力クリア、Timeline表示、削除確認に加え、DetailからのContinuation作成、History表示、History Reviewの古い順表示・件数・Detail遷移、Timeline反映をidentifierベースで検証します。

```bash
xcodebuild -project AiTextApp.xcodeproj -scheme AiTextApp \
  -destination 'platform=iOS Simulator,name=iPhone SE (3rd generation)' test
```

キーボード表示、140文字、複数件、Dynamic Type、Light/Dark mode、VoiceOver label、Share Sheet保存先に加え、AI要約の送信確認／loading／失敗／再試行／Mock表示／再要約、Files／iCloud Drive picker、security-scoped bookmarkの再起動後再利用、保存先失効時表示、Restore後の再起動をSimulator／実機で手動確認します。

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
