# Testing

## Test Strategy

UI非依存のドメイン／永続化／ExportはSwift PackageとしてLinux/macOS共通で検証します。SwiftUI appとXCUITestはmacOS/XcodeのSimulatorで検証します。

## Unit / Persistence Test

```bash
swift test
```

入力境界、SQLite、Persona、AI Reply／Context、タグ、ローカル分析、backup、Export、Historyに加え、Daily Summary v2のHuman／AI分類、Humanタグ限定、AIタグ候補のHuman index解決／不正index除外／生成時非保存／明示追加、複数AI、Relation、共通時間帯とtimezone境界、空Insight、v1 decode／v2 round-trip、SQLite再読込、stale previewを検証します。

Persona External Brain／External Brain Routing v1はAGENT.md解析、`{current_project}`展開、unsafe path拒否、Markdown front matter／heading chunk／draft除外、SHA差分同期・削除・offline cache、FTS route／metadata優先、最大件数、0件、AI Reply／Persona Post promptの参考資料境界とUsage metadataを`ExternalBrainTests.swift`で検証します。

AI API Usage Analyticsは`AIAPIUsageTests.swift`でschema v10保存・再読込、success／failure／cancel／retry、Persona有無、External Brain有無、character、実測tokenのnil保持、Latency、Error分類、今日／7日／30日／全期間と各dimension、本文系columnを持たないprivacy、Telemetry書込失敗時の生成結果維持を検証します。

## UI Test

`AiTextAppUITests`は既存Timeline Composerに加え、Quick Captureの起動、空draft、自動focus、trim投稿、Timeline即時反映、単一投稿、空／141文字拒否、空キャンセル、入力中破棄確認・継続時保持、投稿失敗時の画面・draft保持を検証します。custom URLのcold launch／foreground受信、通常起動ではTimelineのままであること、route dismiss後の消費も検証対象です。本文検索、Thoughtに紐づくタグ、Continuation、Daily Summaryのflowも維持します。

ローカル分析UIは「Timelineで1件投稿 → 分析を開く → 今日／7日／30日／活動日／活動日平均 → 日別カレンダーの今日が1件」をXCUITestで確認します。日別カレンダーの配置・濃淡・今日の枠線、locale曜日、時間帯、タグEmpty State、Continuation説明はSimulatorで目視とVoiceOver確認も行います。

```bash
xcodebuild -project AiTextApp.xcodeproj -scheme AiTextApp \
  -destination 'platform=iOS Simulator,name=iPhone SE (3rd generation)' test
```

キーボード表示、140文字、複数件、Dynamic Type、Light/Dark mode、VoiceOver label、Share Sheet保存先に加え、メンション付きThoughtのAI返信プレビュー／送信／生成中disable／Detail返信表示、AI要約の送信確認／loading／失敗／再試行／Mock表示／再要約、Files／iCloud Drive picker、Restore後の再起動をSimulator／実機で手動確認します。

## Build

```bash
xcodebuild -project AiTextApp.xcodeproj -scheme AiTextApp \
  -destination 'platform=iOS Simulator,name=iPhone SE (3rd generation)' build
```

最新標準iPhone名は`xcrun simctl list devices available`で確認してdestinationへ指定します。

WidgetはXcodeで`AiTextAppWidget` targetのcompile／署名、systemSmall preview、ホーム画面への配置を確認します。Widget全体タップからcold launch／foregroundの両方でQuick Captureが開き、入力欄がfocusされることを確認します。ExtensionのSources／Link Binary With LibrariesにThoughtCore、SQLite、Firebaseが含まれず、App Groups entitlementがないことも確認します。

## Firebase Integration / Device

Daily SummaryはThoughtがある日／ない日、要約済み状態、過去月移動、送信前payload、構造化各Section、再起動後の復元を確認します。実通信ではJSON応答が保存され、タグ／Thought／Continuationが変更されないことを確認します。

XcodeでFirebase package resolveとapp targetのcompileを行った後、Debug Providerを登録したSimulator、App Attestを登録した実機の順で明示送信を確認します。成功時のSQLite provider／model、未設定plist、未登録Debug token、App Check拒否、offline、429／quota、その他API、空応答を確認します。Console設定や実APIを必要とする検証は通常のUnit Testへ組み込みません。

## General Checks

Windowsで実装済み・Mac未検証の蓄積と一括実施順は`MAC_VALIDATION.md`を参照します。

```bash
git diff --check
git status --short
git ls-files
```
