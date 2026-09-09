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
- Firebase AI Logic用Geminiクライアントadapter（SDK／Firebase設定未接続時はMockで動作）。
- `latest`／`previous`の外部2世代、version・schema・サイズ・SHA-256を持つmanifest、作成後検証と失敗時rollback。
- security-scoped bookmarkによる保存先再利用、Restore事前検証・確認UI・次回起動前のatomic適用と現DB rollback。

## 未実装

- Firebase SDK追加、Firebase AI Logic／Gemini Developer API設定、App Check、実Geminiクライアントのcomposition rootへの接続。
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
3. AI要約の送信確認、Mock表示、loading、通信失敗、再試行、Thoughtなし、再要約を手動確認する。
4. AI要約を含むReview画面をLight／Dark Mode、Dynamic Type、VoiceOverで確認する。
5. Firebase設定完了後、`FirebaseAILogic`／`FirebaseAppCheck`を追加し、Debug App Check tokenを登録して実通信を確認する。
6. 配布前にApp Attest等の本番App Check provider、quota超過、offline、timeout時の挙動を実機確認する。
7. 実機でShare Sheet（Files、AirDrop）、外部backup／Restoreを回帰確認する。

### 次の実装候補

1. AI要約履歴画面 — 同期間の過去要約を表示・比較し、再要約が追記保存されている価値を利用者へ返す。
2. AI要約の削除 — Thought原文に触れず、不要な派生情報だけを端末から削除できるようにする。
3. 要約対象の明示プレビュー — 送信確認前に対象件数と期間を表示し、送信範囲をさらに分かりやすくする。
4. 要約のExport — Markdown／JSON Exportで、原文とは別セクションまたは別ファイルとして任意に出力する。
5. AI機能設定 — AI要約の利用可否、privacy説明の再表示、provider／model状態を確認できる設定画面を追加する。
6. 数日間の実利用後にHistory／AI要約／バックアップ／Export運用を再評価する。
