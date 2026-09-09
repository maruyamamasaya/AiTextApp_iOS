# Phase 3-E-2 Widget／外部起動導線 v1

## 状態確認

- `git fetch --all --prune`後、`HEAD`と`origin/main`は`62c84db`で一致（ahead 0／behind 0）。
- 作業開始時点でPhase 3-E-1の未コミット変更が存在したため、それを保持して追加実装した。
- deployment targetはapp／UI TestともiOS 16.0、SwiftUI app lifecycle、生成Info.plist構成だった。

## 判断

- Apple公式のWidgetKit `widgetURL(_:)`はWidget全体タップで包含appへURLを渡せ、SwiftUI `onOpenURL`はcustom URLをsceneで受けられる。iOS 16で使える最小構成として、静的`StaticConfiguration`＋custom URLを採用した。
- URL文字列と検証はapp／Widget共通sourceへ置き、受信時にscheme、host、path、query等を厳密に検証してから既存`AppRoute.quickCapture`へ変換する。
- Widgetは固定文言だけとし、ThoughtCore／SQLite／Firebaseをtargetへ含めない。App Group、DB移動、schema migration、Repository変更は不要。
- App Shortcut／App Intentは同じrouteへ接続可能だが、Widget targetのMac検証を先に行うため3-E-3候補として見送った。

## 変更

- `AiTextAppWidget` Extension target、systemSmall Widget、extension Info.plistを追加。
- appへWidget埋め込みdependencyとcustom URL scheme付きInfo.plistを追加。
- `QuickCaptureRoute`と`onOpenURL` adapter、cold launch／foreground XCUITestを追加。

## 未確認

Windows環境のためXcode project読込、Swift compile、署名、Widget preview／配置、SimulatorでのURL route／focus／投稿、iOS 16／17以降の背景、Dark Mode、Dynamic Type、VoiceOverは未実行。完了扱いにせず`CURRENT.md`へ残した。
