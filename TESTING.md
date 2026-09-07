# Testing

## Test Strategy

UI非依存のドメイン／永続化はSwift PackageとしてLinux/macOS共通で検証します。SwiftUI appはmacOS/XcodeのSimulatorでbuild・手動確認します。XCUITest targetは未導入です。

## Unit / Persistence Test

```bash
swift test
```

1/140文字、空・空白・141文字の拒否、Character単位の絵文字制限、Unicode、trim、SQLite query順序、soft delete、DB再読込、JSON migrationの成功・空・冪等・失敗を検証します。

## UI Test

自動UI testは未導入です。投稿後の入力クリア、キーボードdismiss、削除メニューと確認のキャンセル／確定、Dynamic Type、Light/Dark mode、小型iPhone、VoiceOver labelはSimulatorで手動確認が必要です。

## Build

macOS/Xcodeで以下を実行します。

```bash
xcodebuild -project AiTextApp.xcodeproj -scheme AiTextApp \
  -destination 'platform=iOS Simulator,name=iPhone SE (3rd generation)' build
```

## General Checks

```bash
git diff --check
git status --short
git ls-files
```
