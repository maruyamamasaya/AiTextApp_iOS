# Architecture

この文書は将来構想ではなく、2026-09-07時点でリポジトリに存在する構成を記録します。

## System Overview

```text
Quick Capture Widget -> custom URL -> SwiftUI onOpenURL -> AppRoute.quickCapture
SwiftUI AppRoute -> TimelineView / QuickCaptureView
  TimelineView -> HistoryReviewView / ThoughtDetailView / Continuation Composer
  TimelineView -> ThoughtAnalyticsView
  -> ThoughtStore (presentation state)
    -> ThoughtTimeline (validation/order/delete use cases)
      -> ThoughtRepository / ThoughtTagRepository protocols
        -> SQLiteThoughtRepository (Application Support SQLite)
      -> ThoughtContinuationRepository (Thought + Relation transaction)
    -> ThoughtRelationRepository (History relation queries)
    -> LoadThoughtAnalytics -> ThoughtAnalyticsRepository (read-only SQLite aggregates)
    -> GenerateReviewSummary -> ReviewSummaryClient / ReviewSummaryRepository
    -> ReviewSummaryExporter -> ReviewSummaryRepository -> ShareSheet
    -> ThoughtExporter -> ThoughtRepository
    -> ShareSheet (UIActivityViewController)
    -> ExternalBackupManager -> ExternalBackupService / RestoreCoordinator
```

## Technology Stack

- Swift 5 language mode、SwiftUI、Combine、Foundation。
- iPhone / iOS 16.0以降。Firebase Apple SDK（FirebaseCore／FirebaseAILogic／FirebaseAppCheck）はapp targetだけが依存し、ThoughtCoreはSDK非依存。
- Xcode projectと、CoreのLinuxテストにも使うSwift Package。

## Main Components

- `TimelineView`: placeholder付きComposer、Lazy Timeline、Quick Capture／Detail／Thought検索／History ReviewへのNavigation、相対日時、操作メニュー、削除確認、Empty State、エラー表示。
- `AppRoute` / `QuickCaptureView`: scene直下のQuick Capture表示routeと、独立draft、自動focus、文字数、投稿、破棄確認だけを持つ集中入力画面。将来の外部起動元は同じrouteを要求する。
- `QuickCaptureWidget` / `QuickCaptureRoute`: systemSmallの固定表示Widgetと、app／Extension間で共有する外部URL契約。Widgetは`widgetURL`だけを発行し、appの`onOpenURL`が既存`AppRoute.quickCapture`へ変換する。
- `HistoryReviewView`: 今日／昨日／過去7日／今週／過去30日／今月／日付指定、単一タグ絞り込み、期間・表示件数・活動日数の概要、日単位group、古い順のThought、Continuation件数、最新AI要約と要約履歴への入口を表示。
- `ThoughtAnalyticsView`: 直近30日の基本サマリー、日別／曜日別／時間帯別分布、上位タグ、Continuation件数を標準SwiftUIの縦Sectionと簡易バーで表示する完全ローカル画面。
- `ReviewSummaryHistoryView`: 選択期間に保存された要約を新しい順に並べ、最新表示、生成日時、対象件数、provider／model、確認付き個別削除を提供。
- `ReviewSummaryExporter`: 要約IDをRepositoryで再確認し、単一の保存済み要約をMarkdownまたはJSON schema v1へ変換して一時ファイルへatomic write。
- `GenerateReviewSummary`: 選択期間のThought本文だけからpromptを作り、抽象化されたclientを呼び、原文と別の要約repositoryへ保存。
- `PrepareReviewSummary`: Repositoryから指定Review期間を再取得し、表示対象Thoughtと最終`ReviewSummaryRequest`を同じimmutable previewへ固定。
- `ReviewSummaryClient`: MockとFirebase AI Logic clientを差し替える通信境界。通常起動はFirebase、UIテスト／CoreテストはMockを使用。
- `ReviewSummaryGeneratingTransport`: Firebase SDK importをapp layerへ閉じ込め、request変換、応答変換、空応答、typed errorを外部通信なしでテストする境界。
- `ThoughtDetailView`: 現在Thought、縦型History、削除済みplaceholder、「続きを書く」Composerを表示。
- `ThoughtStore`: Timeline／本文検索／タグ／Continuation draftとHistory画面状態を各use caseへ接続。
- `ThoughtTimeline`: 投稿validation、日時降順sort、soft delete、保存の調停。
- `Thought` / `ThoughtDraft`: 原文モデルと140文字ルール。
- `ThoughtRepository`: create、Timeline query、literal部分一致検索、日付範囲query、ID取得、全件取得、soft deleteの保存境界。
- `ThoughtTag` / `ThoughtTagRepository`: Thought原文から独立したタグ、正規化、付与・解除transaction、Thought別／全タグ／タグ別Thought queryの境界。
- `ThoughtAnalytics` / `ThoughtAnalyticsRepository`: typed集計結果、Calendar由来の日／時間帯境界、SQLite集計専用read境界。CRUD RepositoryやAI通信から分離する。
- `ThoughtRelation`: Thought本文から独立した文脈モデル。sourceは新しいThought、targetは元のThoughtで、Phase 2-Aは`continues`のみ。
- `ThoughtRelationRepository`: Relation作成、source／target方向の1ステップ取得境界。
- `ThoughtContinuationRepository`: 新規Thoughtと`continues` Relationを同一transactionで作成する境界。
- `ThoughtHistory`: 現在Thoughtからrootを求め、Relation APIだけで分岐を安定順に取得するuse case。
- `SQLiteThoughtRepository`: schema v4、Thought／Tag／Relation／期間要約query、旧JSON importと2世代backupを所有する正本実装。
- `ThoughtExporter`: Repositoryから未削除Thoughtを取得し、Markdown／JSONを生成。
- `ShareSheet`: ExportファイルをiOS標準共有UIへ渡すUIKit bridge。
- `ExternalBackupManager`: Filesフォルダpicker、security-scoped bookmark、バックアップ状態と確認UIのpresentation境界。
- `ExternalBackupService`: RepositoryのOnline Backup snapshotを外部フォルダへmanifest付きで作成・検証し、`latest`／`previous`をtransaction的に回転。
- `RestoreCoordinator`: 選択世代をApplication Supportへstageしてpending化し、次回起動のRepository生成前に検証・置換・rollbackする境界。

## Data Flow

Timeline入力はBindingで140 Character以内に制限し、Quick Captureは超過を文字数表示して投稿不可にします。どちらも投稿時に前後空白を除去します。use caseはrepositoryへ1件を追加し、SQLiteが非削除レコードを作成日時・IDの降順で返し、SwiftUIが即時再描画します。

Timeline Composerは従来のStore draftを、Quick Captureは表示中だけのView-local draftを所有します。両方とも`ThoughtStore.post(_:)`を経由して同じ`ThoughtTimeline.post`へ渡すため、validation、trim、UUID／日時生成、SQLite保存、Timeline再読込を重複させません。Storeの再入guardとQuick Captureの送信中disableで二重投稿を防ぎ、成功時だけ呼び出し側がdraftを破棄します。失敗時はQuick Captureを閉じず、入力と画面内エラーを保持します。

Timelineは`ScrollView`と`LazyVStack`で構成します。Composerは画面下部に固定したコンパクトな入力バーとし、有効な文字入力中だけ枠内右端に投稿ボタンを表示します。投稿成功時だけ入力とfocusを解除し、Timeline scrollではキーボードをinteractiveに閉じます。行は本文を主役にし、日時と削除メニューを補助情報として表示します。

Thought DetailはrootからContinuationをdepth-firstで並べた静かな縦型Historyです。現在位置を控えめな背景とlabelで示し、削除済みThoughtはRelationを切らず「削除されたThought」と表示します。Continuation成功後は新Thoughtを現在位置にし、同じThoughtをTimelineにも即時反映します。

History ReviewはCalendarの日境界から期間を作り、開始inclusive／終了exclusiveのSQLite queryで対象Thoughtだけを取得します。日付、`createdAt`、UUIDの順で古いThoughtから安定表示し、soft delete済みは除外します。Continuation件数は対象IDをまとめた1 queryで取得します。

過去7日／過去30日は今日を含む連続した7／30暦日、今週は端末Calendarの週開始日から今日末まで、今月は月初から今日末までです。単一タグ選択時は`thoughts`と`thought_tags`をSQLiteでJOINし、同じ期間境界と昇順規則で絞ります。UIで期間全件を取得してからタグfilterはしません。概要の活動日数と日別groupは、絞り込み済みの少量なReview結果を端末Calendarの日境界でまとめます。

AI要約の保存・履歴・previewは期間境界だけを正本としているため、タグ絞り込みは適用しません。Storeは期間全件数と表示用タグ絞り込み結果を分離し、AI準備処理は従来の`ThoughtRepository.fetchThoughts(from:to:)`を使います。タグ選択中はこの対象差をReview上部へ表示します。

ローカル分析は今日を含む直近30暦日を固定対象にします。Coreが端末Calendar／timezoneから30個の日境界と各日の0／6／12／18時境界を生成し、SQLiteは境界CTEへactive ThoughtをLEFT JOINして日別・時間帯別に`COUNT`／`GROUP BY`します。曜日分布は日別集計だけをCalendar weekdayへ畳み込み、ViewへThought原文全件を渡しません。タグは期間内active ThoughtをJOINして件数降順・正規化名・ID順の上位5件、Continuationは期間内のactiveな親子が持つ`continues` Relationの親distinct件数です。集計はSELECTだけでbackupやDB更新を行いません。

Thought検索はtrim後の空文字をUI stateで初期状態として扱い、非空文字だけを`ThoughtRepository.search(query:)`へ渡します。SQLite実装は`%`、`_`、escape文字をliteralへescapeしたbind parameterを`LIKE ... ESCAPE`へ渡し、`deleted_at IS NULL`で絞って作成日時・UUIDの降順で返します。SwiftUIはSQLを知らず、将来FTSへ移行する場合もRepository実装を差し替える境界です。検索はread-onlyでbackup作成を含むDB更新を行いません。

タグは表示名を前後trimしてUnicode正規合成し、POSIX localeの小文字表現を`normalized_name`として一意化します。Thought Detailからの追加は、タグの`INSERT OR IGNORE`と`thought_tags`付与を同一transactionで行います。解除も中間行だけをtransaction内で削除し、Thought本文とタグmasterは変更しません。Timeline／本文検索は本文queryと分離したタグ取得を表示に合成し、タグ絞り込みは`ThoughtTagRepository`の独立queryを使います。

AI要約はHistory Reviewのボタン押下後に送信前プレビューを作り、対象期間、件数、payload／本文文字数、日時順のThought本文を表示します。キャンセルではclientを呼びません。送信確定時は期間内ThoughtをRepositoryから再取得し、プレビューのsnapshotと完全一致する場合だけ、プレビューに固定済みの同じ`ReviewSummaryRequest`をclientへ渡します。期間またはThoughtが変わっていれば送信を中止してReviewを再読込します。promptへUUID、Relation、SQLite情報、アプリ状態は含めません。成功結果は同一期間への追記として保存するため再要約履歴を失わず、Reviewには最新結果、履歴画面には全結果を新しい順で表示します。通常起動でFirebase未設定なら送信せず設定エラーとなり、UIテストはMockで同じ保存経路を確認します。

AI要約の削除は`ReviewSummaryRepository.deleteSummary(id:)`を通じ、一意な要約IDに一致する1レコードだけを物理削除します。期間条件やThought tableをDELETE対象に使いません。成功後はStoreの現在期間一覧から同じIDだけを除き、先頭を最新要約として選び直します。0件ならReviewは要約未生成状態へ戻ります。

AI要約Exportは履歴内の明示操作で形式を選び、IDで再取得できた1件だけを既存Share Sheetへ渡します。Export documentは期間、要約本文、生成日時、対象件数、provider、modelだけを持ち、Thought本文、送信prompt、secret、Firebase設定、内部pathのfieldを持ちません。JSONの`period.endExclusive`はReview queryと同じ終了排他境界です。ExportはSQLiteを更新しません。

## Persistence

Widget Extensionは永続化層をリンクせず、固定表示とQuick Capture URLだけを持ちます。App Group、共有container、SQLite path変更はなく、既存appだけがApplication Support内の正本DBを読み書きします。

`Application Support/ThoughtTimeline/thought-timeline.sqlite3`が正本です。日時はUnix epoch秒の`REAL`、UUIDは`TEXT`で保存し、削除は`deleted_at`を設定するsoft deleteです。schema v4は`tags`と`thought_tags`を追加し、正規化名のUNIQUE制約、Thought／Tag外部キー、複合主キーを持ちます。soft deleteでは中間行を保持し、通常のタグqueryがdeleted Thoughtを除外します。既存の`thought_relations`と`review_summaries`は維持します。初回に旧`thoughts.json`があればtransaction内で`INSERT OR IGNORE`し、各IDの主要データを照合してmigration markerを記録します。JSONは削除しません。

初期化成功後とcreate／soft delete成功後にSQLite Online Backup APIでスナップショットを作り、`.backup.1`と`.backup.2`だけを保持します。バックアップ失敗は成功済み投稿を失敗扱いにせずログへ記録し、破損時の自動巻き戻しは行いません。

外部完全バックアップは選択されたFilesフォルダ配下の`AiText Backup/latest`と`previous`に、SQLite全体と`manifest.json`を保存します。作成中はUUID付き一時directoryを使い、integrity、schema、サイズ、SHA-256を検証できた新snapshotだけをlatestへ切り替えます。Restoreは外部ファイルを直接正本にせずApplication Supportへcopy・再検証してpendingにし、次回起動時にSQLite connection生成前に正本・WAL・SHMをrollback用へ退避して適用します。適用後のSQLite確認が失敗すれば元の組を戻します。

## External Services / Authentication

application composition rootはローカル`GoogleService-Info.plist`を検証し、DebugではApp Check Debug Provider、ReleaseではApp Attest Providerを設定してからFirebaseを初期化します。モデルは`ReviewSummaryAIConfiguration`の`gemini-3.7-flash`、providerは`firebase-ai-logic`を正本とし、実応答の保存メタデータへ渡します。Firebase未設定、App Check、rate limit、network、その他APIをtyped errorへ分類します。APIキーとDebug tokenはコード／Gitへ含めません。Files／iCloud DriveアクセスにはiOS標準document pickerとsecurity-scoped bookmarkだけを使います。
