# Current Project Status

最終照合日: 2026-09-09

## Project

`AiTextApp_iOS` は、140文字以内のThoughtを端末内に残すSwiftUI製iPhoneアプリです。

## 現在のフェーズ

Phase 3-D（ローカル分析 v1）までコード実装済みです。Phase 3-A〜3-E-2と同様、Windows環境のためSwift／Xcode検証は未実行で、Macでの確認後に完了判定します。

## 実装済み

- 140文字制限、空白除去、空投稿防止を備えた投稿Composer。
- 新しい順のTimeline、投稿日時、削除確認と即時反映。
- UUIDと作成・更新・削除日時を持つThought原文モデル。
- Application Support配下のSQLiteを正本にしたローカル保存、query順序、ソフトデリート。
- 既存JSONをtransaction内で検証して一度だけ取り込む、再実行可能なmigration。
- `PRAGMA user_version`によるschema version管理（現在v4）。
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
- Timelineから開くThought検索画面。標準`.searchable`で本文の部分一致検索を入力中に更新し、空入力の初期状態、0件表示、日時、新しい順、Detail遷移を提供。
- `ThoughtRepository.search(query:)`検索境界と、SQLiteのbind済み`LIKE ... ESCAPE` query、テスト用Memory Repository実装。前後空白、`%`／`_`のliteral検索、deleted除外に対応（検索導入自体ではschema変更なし）。
- Thought原文と分離した`ThoughtTag`／`ThoughtTagRepository`、SQLite schema v4の`tags`／`thought_tags`。正規化名と複合主キーでタグ名・付与の重複を防止。
- Thought Detailのタグ確認・編集、既存タグ付与、新規タグ作成、個別解除。Timeline／本文検索結果の最大2件＋省略表示、タグ一覧、タグ別Thought一覧、既存Detailへの遷移。
- タグ追加／解除transaction、deleted Thoughtを除外するタグ一覧・タグ別query、v1〜v3から既存Thoughtを保持するmigration経路。
- History Reviewへ「今週」「過去30日」「今月」を追加。端末Calendarの週開始・timezoneを尊重し、すべて開始inclusive／終了exclusiveで計算。
- History Reviewの単一タグ絞り込み。期間＋タグをSQLite JOIN queryで絞り、期間、表示件数、Thoughtが存在した日数、タグ状態を概要表示。
- Reviewの日別絶対日付・日別件数と、既存どおり古い日／古いThoughtから読む安定順。タグ切替時の即時再読込とDetail／Continuation件数を維持。
- タグ絞り込みはReview表示だけへ適用し、AI要約・履歴・削除・preview・Exportは従来どおり期間全体を正本とする。タグ選択中は対象差をUIに明示。
- Timelineから1操作で開き、本文入力へ自動focusするQuick Capture。本文、140文字、文字数、投稿、キャンセルだけに絞り、既存Timeline Composerを維持。
- Timeline ComposerとQuick Captureが`ThoughtStore.post(_:)`から既存`ThoughtTimeline.post`を共用する投稿境界。Quick専用Repository API、タグ入力、自動draft保存は追加しない。
- Quick Capture表示中だけ保持する独立draft、入力中キャンセルの破棄確認、interactive dismiss抑止、投稿中の再入防止、失敗時の画面・draft保持、成功時dismissとTimeline即時反映。
- scene直下の`AppRoute.quickCapture`。Widgetのcustom URLは検証後にこのrouteへ変換し、将来のApp Shortcut／Action Buttonも同じ表示routeを要求できる構成。
- iOS 16対応の小型Quick Capture Widget。固定文言だけを表示し、全体タップの`widgetURL`から`aitextapp://quick-capture`を開く。
- app／Widgetで共有する厳密な外部route契約と、SwiftUI `onOpenURL`から既存`AppRoute.quickCapture`へ変換するcold launch／foreground共通導線。
- `AiTextAppWidget` Extension targetとappへの埋め込み設定。WidgetはSQLite、Repository、Firebase、Thought本文へ依存せず、App Group／entitlement／schema変更を行わない。
- Timelineから開くローカル分析画面。今日／過去7日／過去30日、活動日数、1活動日平均、30日の日別・曜日別・時間帯別分布、上位5タグ、Continuationを持つThought数を表示。
- typed分析model、端末Calendarから30日の日／時間帯境界を構築する`LoadThoughtAnalytics`、CRUDから分離したread-only `ThoughtAnalyticsRepository`。
- SQLiteの境界CTE＋`COUNT`／`GROUP BY`、タグJOIN集計、activeな期間内親子のRelation集計。原文全件をViewへ取得せず、deleted／期間外ThoughtをSQLで除外する。

## 未実装

- Firebase ConsoleでのGemini Developer API有効化、iOS app登録、App Check provider／Debug token登録、ローカル`GoogleService-Info.plist`配置。
- AI分類など要約以外の派生情報、クラウド同期、アカウント、その他の外部連携。
- CI/CD、配布用の署名・bundle identifier設定。

## AI要約：実接続確認待ち

ロードマップ5-Aはコード実装まで完了していますが、Mac／Xcode環境でのFirebase実接続を確認するまでは完了扱いにしません。再開時は次を順に実施します。

1. Firebase Apple SDKをresolveしてbuildする。
2. `GoogleService-Info.plist`をローカルのXcode app targetへ追加する。
3. SimulatorでApp Check Debug Providerを起動し、出力されたDebug tokenをFirebase Consoleへ登録する。
4. Gemini実APIでAI要約を1回、送信前プレビューから明示実行する。
5. その時点で実際に利用可能なGemini modelを確認し、必要なら中央設定を更新する。
6. SQLiteに要約本文、実際のprovider／model、対象件数が保存され、履歴に表示されることを確認する。
7. 可能であれば実機とApp Attestでも確認する。
8. 問題がなければロードマップ5-Aを完了へ変更し、結果を踏まえて5-Bの仕様を再評価する。

再開指示は「AI要約の続きを進める」「Gemini連携を再開する」などを目印とし、この地点から再開します。それまではAI機能設定画面や新たなFirebase依存機能を先行実装せず、別分野の開発を優先します。

## 既知の問題

- iPhone SE (3rd generation, iOS 17.4)のbuildとXCUITestは確認済みですが、Light／Dark Modeの手動目視確認は未実施です。
- 破損した移行元JSONは自動復旧せず、SQLiteへの移行を中止してエラー表示し、原本を保持します。
- XCUITestは投稿・削除、Continuation、History Review主要フローをiPhone SE Simulatorで確認済みです。
- App iconの実画像は未設定です。
- Phase 3-AのSwift Testing、Xcode build、XCUITest、Light／Dark Mode、Dynamic Type、VoiceOverの実機／Simulator確認はWindows環境のため未実行です。
- Phase 3-Bのschema v4 migration、タグunit test、XCUITest、Light／Dark Mode、Dynamic Type、VoiceOverの実機／Simulator確認はWindows環境のため未実行です。
- Phase 3-Cの期間境界、期間＋タグquery、Review概要・日別表示、AI対象差、XCUITest、各アクセシビリティ表示はWindows環境のため未実行です。
- Phase 3-E-1の自動focus、140／141文字、二重投稿防止、失敗時draft保持、破棄確認、小型iPhone keyboard layout、XCUITest、VoiceOverはWindows環境のため未実行です。
- Phase 3-E-2のXcode project読込、app／Widget compile・署名、Widget preview、SimulatorへのWidget配置、cold launch／foreground URL route XCUITest、iOS 16／17以降の背景表示、Dynamic Type／Dark Mode／VoiceOverはWindows環境のため未実行です。
- Phase 3-DのSwift Testing、SQLite集計SQL、timezone／時間帯境界、分析画面XCUITest、小型iPhoneでのバー表示、Dynamic Type／Dark Mode／VoiceOverはWindows環境のため未実行です。

## 次に行うこと

### Xcode環境が利用可能になったら行う検証

1. macOSで`swift test`を実行し、schema v4 migration、本文検索、タグ、Review、既存投稿境界、AI要約対象維持を確認する。
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
12. `AiTextAppWidget`をbuild・署名し、systemSmallをホーム画面へ配置して、cold launch／foregroundの両方でQuick Captureへ遷移し自動focusすることを確認する。
13. Widget経由で既存の空／140／141文字validation、trim、単一投稿、失敗時draft保持、投稿後Timeline反映を確認する。
14. `swift test`でローカル分析の件数、日別／曜日／時間帯、タグ、Continuation、read-only性と既存Repository回帰を確認する。
15. Timelineから分析画面を開き、小型iPhone、Dynamic Type、Dark Mode、VoiceOverで30日分の可読性を確認する。

### 次の実装候補

#### 非AIロードマップ

1. Phase 3-A: Thought検索 v1 — コード実装済み／Mac確認待ち。
2. Phase 3-B: Thoughtタグ v1 — コード実装済み／Mac確認待ち。
3. Phase 3-C: History Review強化 v1 — コード実装済み／Mac確認待ち。
4. Phase 3-E-1: Quick Capture v1 — コード実装済み／Mac確認待ち。
5. Phase 3-E-2: Widget／外部起動導線 v1 — コード実装済み／Mac確認待ち。WidgetはQuick Captureを開くだけで、データ共有・直接投稿を行わない。
6. Phase 3-E-3候補: 「Thoughtを書く」App Shortcut／App Intent — 既存外部routeを再利用できるが、WidgetのMac検証後に必要性を判断する。
7. Phase 3-D: ローカル分析 v1 — コード実装済み／Mac確認待ち。SQLite集計基盤と直近30日の小さな分析画面まで。

Phase 3の機能追加は一度止め、次はMac検証を最優先する。3-A〜3-E-2と3-Dにcompile／Simulator未確認が蓄積し、特にWidget targetとSQLite分析SQLは実環境確認が完了条件になるためである。検証と実利用後、入力導線の不足が明確なら3-E-3 App Shortcut、分析画面で具体的な意思決定が不足する場合だけ分析v2を検討する。根拠がなければPhase 4の別テーマを決める。

#### AIロードマップ

1. 完了: AI要約履歴画面 — 同期間の過去要約を新しい順に表示し、生成日時、対象件数、生成元を確認可能。
2. 完了: AI要約の削除 — 要約ID単位の確認付き削除。Thought原文、別期間、他要約には影響しない。
3. 完了: 要約対象の明示プレビュー — 期間、件数、文字数、日時順本文を確認し、確定したpayloadだけを送信する。
4. 完了: 要約のExport — 選択した要約と安全なメタデータだけをMarkdown／JSONで個別共有する。
5. 5-Aコード側完了／接続確認保留: Firebase AI Logic／App Checkをcomposition rootへ接続。Console、plist、Xcode build、Simulator／実機通信は上記のとおり未確認。
6. 保留 5-B: AI機能設定画面 — 5-Aの実接続確認後に仕様を再評価する。確認前は先行実装しない。
7. 数日間の実利用後にHistory／AI要約／バックアップ／Export運用を再評価する。
