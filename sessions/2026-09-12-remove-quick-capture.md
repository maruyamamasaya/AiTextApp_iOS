# Quick Capture removal

## Changes

- Timeline右上のQuick Captureボタン、`QuickCaptureView`、`AppRoute.quickCapture`、custom URL受信を削除。
- Quick Captureだけを開くWidget Extension、共有URL route、appのURL schemeを削除。
- Quick Capture専用accessibility identifierとXCUITest、失敗注入用repositoryを削除。
- Timeline下部Composerと`ThoughtStore.post(_:)`、Mention保存処理は維持。
- Xcode projectとCURRENT／ARCHITECTURE／CODEMAP／TESTING／MAC_VALIDATIONを現行実装へ同期。

## Verification

- `plutil -lint AiTextApp/Info.plist AiTextApp.xcodeproj/project.pbxproj`: success。
- `swift test`: 115 tests、11 suites、全件成功。140文字境界、通常投稿、Mentionのatomic保存、AI Reply、Daily Summary、検索、分析などを含む。
- Debug iOS Simulator build（Xcode 26.6、iOS Simulator SDK 26.5、code signingなし）: success。
- iPhone SE (3rd generation) / iOS 17.4 XCUITest: 8件中4件成功、4件失敗。通常Composer投稿・削除、Continuation、タグ、分析は成功。`@myself メンション確認`の投稿とMentions表示も後続assertionまで成功した。
- UI Test失敗は並行して存在していたタブ構成変更に対する期待値不整合（Profileの旧ラベル、Searchの旧navigation title、Reply後のHome tab復帰など）。Quick Capture削除箇所のcompile errorや参照残りはなし。
