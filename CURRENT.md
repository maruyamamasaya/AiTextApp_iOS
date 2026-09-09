# Current Project Status

最終照合日: 2026-09-09

## Project

`AiTextApp_iOS` は、140文字以内のThoughtを端末内に残すSwiftUI製iPhoneアプリです。

## 現在のフェーズ

Phase 2-C（History Review / 時間軸でThoughtを振り返る）の実装を完了しています。

## 実装済み

- 140文字制限、空白除去、空投稿防止を備えた投稿Composer。
- 新しい順のTimeline、投稿日時、削除確認と即時反映。
- UUIDと作成・更新・削除日時を持つThought原文モデル。
- Application Support配下のSQLiteを正本にしたローカル保存、query順序、ソフトデリート。
- 既存JSONをtransaction内で検証して一度だけ取り込む、再実行可能なmigration。
- `PRAGMA user_version`によるschema version管理（現在v3）。
- 画面下部に固定し、入力中だけ枠内右端に投稿ボタンを表示するコンパクトなComposer。
- Lazy Timeline、自然な相対日時、メニュー内削除、Empty State。
- interactiveなキーボードdismiss、Dynamic Type、Dark Mode、VoiceOver向けsemantic UI。
- iOS 16以降用SwiftUIアプリ、Xcode project/shared scheme。
- 投稿ルール、順序、Unicode、削除、ファイル再読込のSwift Testingテスト。
- Repository経由のMarkdown／JSON ExportとiOS標準Share Sheet。
- SQLiteの直近2世代ローリングバックアップ。
- 投稿・削除主要フローのXCUITest target。
- Thought本文と分離した`ThoughtRelation`モデル（`continues`）と、source=新しいThought／target=元Thoughtの固定方向。
- SQLite schema v2、Relationの外部キー・index・重複／self relation制約。
- parent／continuationの1ステップ取得と、Thought作成＋Relation作成の原子的transaction境界。
- Soft Delete後もRelationを保持するThought History基盤と、単純なcycle防止。
- Timelineから開くThought Detail、現在位置を示す縦型History、履歴内移動。
- 既存140文字ルールとatomic transactionを使う「続きを書く」Composer。
- 分岐Continuationの安定順表示と、削除済みThoughtのHistory placeholder。
- Timeline／History／Continuation操作のVoiceOver labelとaccessibility identifier。
- 今日／昨日／過去7日／日付指定で開けるHistory Reviewと、日ごとの件数表示。
- `createdAt`昇順の安定したReview表示、Thought Detailへの遷移、Continuation件数の軽量表示。
- SQLiteの日付範囲query（開始inclusive／終了exclusive）とRelation件数の一括query。
- Files／iCloud Driveのユーザー選択フォルダへSQLite Online Backup APIの完全snapshotを保存する外部災害復旧バックアップ。
- History Reviewの選択期間を明示操作時だけ要約するAI要約UI、送信前確認、Mockクライアント、再要約、失敗時再試行。
- Thought原文と分離したSQLite schema v3の`review_summaries`と、通信／保存を抽象化した要約use case。
- Firebase Apple SDK 12.17.0以降の`FirebaseAILogic`／`FirebaseAppCheck`／`FirebaseCore`依存と、通常起動でFirebase AI Logicを選ぶcomposition root。
- `PrepareReviewSummary`の確定promptを変更せず送るFirebase transport、中央管理した`firebase-ai-logic`／`gemini-3.7-flash`、成功時だけ既存SQLite保存へ進む実クライアント。
- Firebase未設定、App Check、rate limit、network、その他API、空応答を区別するエラー境界。DebugはApp Check Debug Provider、ReleaseはApp AttestをFirebase初期化前に設定する。
- SDK非依存transportによるFirebaseクライアント変換テスト。MockクライアントはCore／UIテスト用として維持。
- 選択期間ごとのAI要約履歴画面。再要約結果を新しい順に表示し、最新、生成日時、対象件数、生成元を確認可能。
- AI要約履歴から要約ID単位で削除する確認付き操作。最新要約の再選択、全件削除後の未生成表示、失敗表示に対応。
- AI要約の送信前プレビュー。対象期間、件数、最終payload文字数、本文文字数、日時順Thoughtを表示し、明示確定時だけ送信。
- プレビュー時の最終requestを固定し、送信直前に期間内Thoughtを再取得して一致しない場合は送信を中止する整合性確認。
- AI要約履歴の各レコードをMarkdown／JSONで個別Exportする形式選択とiOS標準Share Sheet導線。
- Thought本文・promptを含まないAI要約専用Export modelと、将来の解析／再Importを見据えたJSON schema v1。
- `latest`／`previous`の外部2世代、version・schema・サイズ・SHA-256を持つmanifest、作成後検証と失敗時rollback。
- security-scoped bookmarkによる保存先再利用、Restore事前検証・確認UI・次回起動前のatomic適用と現DB rollback。

## 未実装

- Firebase ConsoleでのGemini Developer API有効化、iOS app登録、App Check provider／Debug token登録、ローカル`GoogleService-Info.plist`配置。
- AI分類など要約以外の派生情報、クラウド同期、アカウント、その他の外部連携。
- CI/CD、配布用の署名・bundle identifier設定。

## 既知の問題

- iPhone SE (3rd generation, iOS 17.4)のbuildとXCUITestは確認済みですが、Light／Dark Modeの手動目視確認は未実施です。
- 破損した移行元JSONは自動復旧せず、SQLiteへの移行を中止してエラー表示し、原本を保持します。
- XCUITestは投稿・削除、Continuation、History Review主要フローをiPhone SE Simulatorで確認済みです。
- App iconの実画像は未設定です。

## 次に行うこと

### Xcode環境が利用可能になったら行う検証

1. macOSで`swift test`を実行し、schema v3 migration、AI要約prompt、Mock生成、再要約保存を確認する。
2. iPhone SEと最新標準iPhone Simulatorでbuild／XCUITestを実行する。
3. AI要約プレビューの期間・件数・文字数・Thought順序、キャンセル、確定後のMock表示、loading、通信失敗、再試行、Thoughtなし、再要約を手動確認する。
4. プレビュー表示後に対象Thoughtが変わった場合、AIを呼ばず対象再読込エラーになることを確認する。
5. AI要約履歴で削除キャンセル、個別削除、最新切替、全件削除後の空状態、削除失敗表示を確認する。
6. AI要約履歴のMarkdown／JSON形式Menu、ファイル名、Share Sheet、Files／AirDrop保存、削除済み要約の拒否を確認する。
7. AI要約を含むReview画面をLight／Dark Mode、Dynamic Type、VoiceOverで確認する。
8. XcodeでFirebase Apple SDK 12.17.0以降をresolveし、`FirebaseCore`／`FirebaseAILogic`／`FirebaseAppCheck`のcompileを確認する（Windowsでは未実行）。
9. Firebase Consoleから取得した`GoogleService-Info.plist`をローカルでapp targetへ追加し、Debug Providerの出力tokenをConsoleへ登録してSimulator実通信を確認する。plist／tokenは未配置・未コミット。
10. 実機でApp Attest entitlement／provider、AI Logic実通信、保存されるprovider／model、Firebase未設定、App Check拒否、quota超過、offline、timeout、空応答を確認する（未実行）。
11. 実機で既存Thought Share Sheet（Files、AirDrop）、外部backup／Restoreを回帰確認する。

### 次の実装候補

1. 完了: AI要約履歴画面 — 同期間の過去要約を新しい順に表示し、生成日時、対象件数、生成元を確認可能。
2. 完了: AI要約の削除 — 要約ID単位の確認付き削除。Thought原文、別期間、他要約には影響しない。
3. 完了: 要約対象の明示プレビュー — 期間、件数、文字数、日時順本文を確認し、確定したpayloadだけを送信する。
4. 完了: 要約のExport — 選択した要約と安全なメタデータだけをMarkdown／JSONで個別共有する。
5. 5-Aコード側完了／接続確認保留: Firebase AI Logic／App Checkをcomposition rootへ接続。Console、plist、Xcode build、Simulator／実機通信は上記のとおり未確認。
6. 次候補 5-B: AI機能設定画面 — AI要約の利用可否、privacy説明の再表示、接続状態、provider／model、App Check環境を読み取り専用で表示する。API key入力やモデル自由入力、自動送信は設けない。
7. 数日間の実利用後にHistory／AI要約／バックアップ／Export運用を再評価する。
