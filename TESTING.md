# Testing

## Test Strategy

UI非依存のドメイン／永続化／ExportはSwift PackageとしてLinux/macOS共通で検証します。SwiftUI appとXCUITestはmacOS/XcodeのSimulatorで検証します。

## Unit / Persistence Test

```bash
swift test
```

入力境界、Unicode、SQLite順序、soft delete、再読込、内部2世代backup、JSON migration、Markdown／JSON Export、Continuation、分岐History、Review、AI要約promptの送信項目、各Review期間のpreview対象、件数／文字数、準備時client未呼出、確定request一致、変更後preview拒否、Mock生成、Firebase transportへの確定prompt／model変換、provider／model応答、空応答、未設定／network／rate limit／API／App Check分類、再要約と原文分離保存、要約ID単位削除、AI要約Markdown／JSON同値性と秘密情報除外、削除済み要約Export拒否、Thought原文・別期間・他要約の保持に加え、外部backup／Restoreを検証します。Firebase SDKと実通信はUnit Testに含めません。

## UI Test

`AiTextAppUITests`は空投稿不可、投稿後入力クリア、Timeline表示、削除確認に加え、DetailからのContinuation作成、History表示、History Reviewの古い順表示・件数・Detail遷移、Timeline反映、AI要約preview表示・キャンセル・確定後保存、Mock AI再要約後の要約履歴件数・最新表示・個別Export形式Menu・削除キャンセル・最新切替・全件削除後の空状態をidentifierベースで検証します。

```bash
xcodebuild -project AiTextApp.xcodeproj -scheme AiTextApp \
  -destination 'platform=iOS Simulator,name=iPhone SE (3rd generation)' test
```

キーボード表示、140文字、複数件、Dynamic Type、Light/Dark mode、VoiceOver label、Share Sheet保存先に加え、AI要約の送信確認／loading／失敗／再試行／Mock表示／再要約、要約履歴の新しい順・最新表示・期間切替、Files／iCloud Drive picker、security-scoped bookmarkの再起動後再利用、保存先失効時表示、Restore後の再起動をSimulator／実機で手動確認します。

## Build

```bash
xcodebuild -project AiTextApp.xcodeproj -scheme AiTextApp \
  -destination 'platform=iOS Simulator,name=iPhone SE (3rd generation)' build
```

最新標準iPhone名は`xcrun simctl list devices available`で確認してdestinationへ指定します。

## Firebase Integration / Device

XcodeでFirebase package resolveとapp targetのcompileを行った後、Debug Providerを登録したSimulator、App Attestを登録した実機の順で明示送信を確認します。成功時のSQLite provider／model、未設定plist、未登録Debug token、App Check拒否、offline、429／quota、その他API、空応答を確認します。Console設定や実APIを必要とする検証は通常のUnit Testへ組み込みません。

## General Checks

```bash
git diff --check
git status --short
git ls-files
```
