# Testing

## Test Strategy

UI非依存のドメイン／永続化／ExportはSwift PackageとしてLinux/macOS共通で検証します。SwiftUI appとXCUITestはmacOS/XcodeのSimulatorで検証します。

## Unit / Persistence Test

```bash
swift test
```

入力境界、Unicode、SQLite順序、soft delete、再読込、本文検索、タグ、v4 migration、Review全期間（今日／昨日／過去7日／今週／過去30日／今月／指定日、月跨ぎ、年跨ぎ、timezone）、期間＋単一タグ（タグなし全件、同タグ複数、別タグ・deleted・期間外除外、昇順）、AI要約がタグfilter後も期間全体を対象にする回帰、内部2世代backup、JSON migration、Export、Continuation、分岐History、AI要約prompt／preview／保存／削除／Export、外部backup／Restoreを検証します。Firebase SDKと実通信はUnit Testに含めません。

## UI Test

`AiTextAppUITests`は空投稿不可、投稿後入力クリア、Timeline、削除、本文検索、タグ基本flow、History Reviewの全体／日別件数・活動日数・古い順・Detail遷移、「今月→タグ選択→対象Thought→Detail」、Continuation、AI要約preview／保存／履歴／削除／Exportをidentifierベースで検証します。

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
