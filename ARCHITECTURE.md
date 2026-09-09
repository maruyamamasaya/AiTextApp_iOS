# Architecture

この文書は将来構想ではなく、2026-09-07時点でリポジトリに存在する構成を記録します。

## System Overview

```text
SwiftUI TimelineView -> HistoryReviewView / ThoughtDetailView / Continuation Composer
  -> ThoughtStore (presentation state)
    -> ThoughtTimeline (validation/order/delete use cases)
      -> ThoughtRepository protocol
        -> SQLiteThoughtRepository (Application Support SQLite)
      -> ThoughtContinuationRepository (Thought + Relation transaction)
    -> ThoughtRelationRepository (History relation queries)
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

- `TimelineView`: placeholder付きComposer、Lazy Timeline、Detail／History ReviewへのNavigation、相対日時、操作メニュー、削除確認、Empty State、エラー表示。
- `HistoryReviewView`: 今日／昨日／過去7日／日付指定の期間選択、日単位group、件数、古い順のThought、Continuation件数、最新AI要約と要約履歴への入口を表示。
- `ReviewSummaryHistoryView`: 選択期間に保存された要約を新しい順に並べ、最新表示、生成日時、対象件数、provider／model、確認付き個別削除を提供。
- `ReviewSummaryExporter`: 要約IDをRepositoryで再確認し、単一の保存済み要約をMarkdownまたはJSON schema v1へ変換して一時ファイルへatomic write。
- `GenerateReviewSummary`: 選択期間のThought本文だけからpromptを作り、抽象化されたclientを呼び、原文と別の要約repositoryへ保存。
- `PrepareReviewSummary`: Repositoryから指定Review期間を再取得し、表示対象Thoughtと最終`ReviewSummaryRequest`を同じimmutable previewへ固定。
- `ReviewSummaryClient`: MockとFirebase AI Logic clientを差し替える通信境界。通常起動はFirebase、UIテスト／CoreテストはMockを使用。
- `ReviewSummaryGeneratingTransport`: Firebase SDK importをapp layerへ閉じ込め、request変換、応答変換、空応答、typed errorを外部通信なしでテストする境界。
- `ThoughtDetailView`: 現在Thought、縦型History、削除済みplaceholder、「続きを書く」Composerを表示。
- `ThoughtStore`: Timeline／Continuation draftとHistory画面状態を各use caseへ接続。
- `ThoughtTimeline`: 投稿validation、日時降順sort、soft delete、保存の調停。
- `Thought` / `ThoughtDraft`: 原文モデルと140文字ルール。
- `ThoughtRepository`: create、Timeline query、日付範囲query、ID取得、全件取得、soft deleteの保存境界。
- `ThoughtRelation`: Thought本文から独立した文脈モデル。sourceは新しいThought、targetは元のThoughtで、Phase 2-Aは`continues`のみ。
- `ThoughtRelationRepository`: Relation作成、source／target方向の1ステップ取得境界。
- `ThoughtContinuationRepository`: 新規Thoughtと`continues` Relationを同一transactionで作成する境界。
- `ThoughtHistory`: 現在Thoughtからrootを求め、Relation APIだけで分岐を安定順に取得するuse case。
- `SQLiteThoughtRepository`: schema v3、Thought／Relation／期間要約query、旧JSON importと2世代backupを所有する正本実装。
- `ThoughtExporter`: Repositoryから未削除Thoughtを取得し、Markdown／JSONを生成。
- `ShareSheet`: ExportファイルをiOS標準共有UIへ渡すUIKit bridge。
- `ExternalBackupManager`: Filesフォルダpicker、security-scoped bookmark、バックアップ状態と確認UIのpresentation境界。
- `ExternalBackupService`: RepositoryのOnline Backup snapshotを外部フォルダへmanifest付きで作成・検証し、`latest`／`previous`をtransaction的に回転。
- `RestoreCoordinator`: 選択世代をApplication Supportへstageしてpending化し、次回起動のRepository生成前に検証・置換・rollbackする境界。

## Data Flow

入力はBindingで140 Character以内に制限され、投稿時に前後空白を除去します。use caseはrepositoryへ1件を追加し、SQLiteが非削除レコードを作成日時・IDの降順で返し、SwiftUIが即時再描画します。

Timelineは`ScrollView`と`LazyVStack`で構成します。Composerは画面下部に固定したコンパクトな入力バーとし、有効な文字入力中だけ枠内右端に投稿ボタンを表示します。投稿成功時だけ入力とfocusを解除し、Timeline scrollではキーボードをinteractiveに閉じます。行は本文を主役にし、日時と削除メニューを補助情報として表示します。

Thought DetailはrootからContinuationをdepth-firstで並べた静かな縦型Historyです。現在位置を控えめな背景とlabelで示し、削除済みThoughtはRelationを切らず「削除されたThought」と表示します。Continuation成功後は新Thoughtを現在位置にし、同じThoughtをTimelineにも即時反映します。

History ReviewはCalendarの日境界から期間を作り、開始inclusive／終了exclusiveのSQLite queryで対象Thoughtだけを取得します。日付、`createdAt`、UUIDの順で古いThoughtから安定表示し、soft delete済みは除外します。Continuation件数は対象IDをまとめた1 queryで取得します。

AI要約はHistory Reviewのボタン押下後に送信前プレビューを作り、対象期間、件数、payload／本文文字数、日時順のThought本文を表示します。キャンセルではclientを呼びません。送信確定時は期間内ThoughtをRepositoryから再取得し、プレビューのsnapshotと完全一致する場合だけ、プレビューに固定済みの同じ`ReviewSummaryRequest`をclientへ渡します。期間またはThoughtが変わっていれば送信を中止してReviewを再読込します。promptへUUID、Relation、SQLite情報、アプリ状態は含めません。成功結果は同一期間への追記として保存するため再要約履歴を失わず、Reviewには最新結果、履歴画面には全結果を新しい順で表示します。通常起動でFirebase未設定なら送信せず設定エラーとなり、UIテストはMockで同じ保存経路を確認します。

AI要約の削除は`ReviewSummaryRepository.deleteSummary(id:)`を通じ、一意な要約IDに一致する1レコードだけを物理削除します。期間条件やThought tableをDELETE対象に使いません。成功後はStoreの現在期間一覧から同じIDだけを除き、先頭を最新要約として選び直します。0件ならReviewは要約未生成状態へ戻ります。

AI要約Exportは履歴内の明示操作で形式を選び、IDで再取得できた1件だけを既存Share Sheetへ渡します。Export documentは期間、要約本文、生成日時、対象件数、provider、modelだけを持ち、Thought本文、送信prompt、secret、Firebase設定、内部pathのfieldを持ちません。JSONの`period.endExclusive`はReview queryと同じ終了排他境界です。ExportはSQLiteを更新しません。

## Persistence

`Application Support/ThoughtTimeline/thought-timeline.sqlite3`が正本です。日時はUnix epoch秒の`REAL`、UUIDは`TEXT`で保存し、削除は`deleted_at`を設定するsoft deleteです。schema v3の`thought_relations`は両端を`thoughts.id`へ外部キー参照し、`review_summaries`は期間境界、生成結果、生成日時、provider／model、prompt version、対象件数を原文と分離して保存します。初回に旧`thoughts.json`があればtransaction内で`INSERT OR IGNORE`し、各IDの主要データを照合してmigration markerを記録します。JSONは削除しません。

初期化成功後とcreate／soft delete成功後にSQLite Online Backup APIでスナップショットを作り、`.backup.1`と`.backup.2`だけを保持します。バックアップ失敗は成功済み投稿を失敗扱いにせずログへ記録し、破損時の自動巻き戻しは行いません。

外部完全バックアップは選択されたFilesフォルダ配下の`AiText Backup/latest`と`previous`に、SQLite全体と`manifest.json`を保存します。作成中はUUID付き一時directoryを使い、integrity、schema、サイズ、SHA-256を検証できた新snapshotだけをlatestへ切り替えます。Restoreは外部ファイルを直接正本にせずApplication Supportへcopy・再検証してpendingにし、次回起動時にSQLite connection生成前に正本・WAL・SHMをrollback用へ退避して適用します。適用後のSQLite確認が失敗すれば元の組を戻します。

## External Services / Authentication

application composition rootはローカル`GoogleService-Info.plist`を検証し、DebugではApp Check Debug Provider、ReleaseではApp Attest Providerを設定してからFirebaseを初期化します。モデルは`ReviewSummaryAIConfiguration`の`gemini-3.7-flash`、providerは`firebase-ai-logic`を正本とし、実応答の保存メタデータへ渡します。Firebase未設定、App Check、rate limit、network、その他APIをtyped errorへ分類します。APIキーとDebug tokenはコード／Gitへ含めません。Files／iCloud DriveアクセスにはiOS標準document pickerとsecurity-scoped bookmarkだけを使います。
