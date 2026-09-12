# Current Project Status

最終照合日: 2026-09-12

## Project

`AiTextApp_iOS` は、140文字以内のThoughtを端末内に残すSwiftUI製iPhoneアプリです。

## 現在のフェーズ

Phase 3-D（ローカル分析 v1）までコード実装済みです。2026-09-09にMac/Xcode 26.6でSwift Testing全60件、Firebase 12.18.0を含むDebug／Release Simulator build、Personal TeamのDebug実機向け署名buildを確認しました。XCUITest targetはcompile済みですが、Simulator serviceが起動時に停止するホスト環境障害のため実行確認は未完了です。

## 実装済み

- Gemini／OpenAIのAI Provider切替と用途別生成Profile。AI Personaごとの投稿・手動返信・自動返信はPersona設定でGemini／OpenAIを選択し、両Providerとも`low`、最大出力1,024 tokenで生成する。Daily SummaryはOpenAIの`medium`、最大8,192 tokenへ固定し、Knowledge DraftはSettingsでProviderを選択して`medium`、最大4,096 tokenで生成する。個人所有端末だけへXcodeから導入する暫定運用として、OpenAI API keyは`WhenUnlockedThisDeviceOnly`のKeychainへ保存し、Responses APIへ直接送る。schema v19でPersona設定にproviderを非破壊追加し、生成開始時のprovider／model／generation profileをrequestへ固定する。TestFlight／App Store／第三者配布へ進む前に、API keyを端末から除去してバックエンド＋Secret管理へ移行する。

- Conversation中心のAI返信／投稿履歴。Human ThoughtでactiveなAI Personaを@メンションすると、元ThoughtとMentionを先に保存・表示してから各AIが自動返信する。生成中／失敗／再試行をTimelineとConversationへ表示し、失敗しても元Thoughtを保持する。AI返信は通常Thought＋author＋`repliesTo`＋生成metadataとして保存し、同一対象・同一AIの二重返信を拒否しつつ複数AI返信を許可する。
- `continues`／`repliesTo`を統合する`LoadConversationThread`を追加し、root、nodes、edges、currentPath、leaves、最新leafをDBから再構築する。Thought DetailはConversation表示へ移行し、通常返信は選択Thoughtではなく最新leafへ、過去地点への返信は`…`内の「この投稿から返信を分岐」へ分離した。会話Primary Actionとタグ／Knowledge Draft／削除などの管理操作も分離した。

- AI Persona追加を妨げていた旧`personas.account_id`単独UNIQUE制約をschema v18で非破壊補修する。旧実機DBはPersona tableをtransaction内で再構築し、Humanの`account_id`へ既存／新規AIを所属させる。Thought author、Mention、AI ConfigurationなどのPersona ID参照を維持し、handleの大文字小文字を無視した一意性は継続する。
- ユーザー向け表示の日本語化。Home／Mentions／Search／Insights／Profileの5タブ、各画面タイトル、テーマ、AI使用状況、GitHub接続、外部ブレイン、ナレッジ下書きの主な表示を日本語に統一した。開発ドキュメントも日本語を基本とする。
- 投稿後Navigation統一。Profile > Settings > AIの「AI返信の確認クッション」を任意でONにでき、初期値はOFF、選択は端末へ永続化する。OFFでは手動AI返信も生成からatomic投稿まで連続実行し、ONでは生成内容を確認してから投稿する。@メンションによるPersona AIの自動返信には承認を挟まない。生成・保存失敗時は画面と再試行導線を保持する。通常投稿、Human Reply、Continuation、AI Reply、Persona Postの成功は共通イベントでHome rootへ戻り、新規Thoughtを一時ハイライトする。
- AI Persona管理とPersona Post依頼を分離。AI Personas一覧は各AIのプロフィール／編集へのリンクを中心とし、投稿操作はSettings > AIの独立した「AIに投稿を依頼」画面でPersonaを選択して依頼文を入力し、既存の送信前Previewへ進む。

- UI演出プリセットとしてのTheme v1。Default／Dynamic Aurora／Pulse Neon／Blue Cosmosを`Primitive → Semantic → Theme → Effect`で解決し、Home／Mentions／Searchは静かな強度、Insights／Profileは強めの強度で同じ画面構造へ適用する。Profile > Settings > Appearance / Themeでライブプレビュー付き選択を行い、UserDefaultsへ永続化する。AI Thoughtは本文を発光させず専用Edge／Glowだけを加え、Reduce Motion時はambient animationを停止する。

- @ID／Mention／Reply v1。HumanとAI Personaを不変UUIDの共通Actorとして扱い、3〜30文字の一意な小文字handleを設定できる。Composerの`@`候補はHuman／AIを表示し、保存時にActor ID・handle snapshot・UTF-16範囲をschema v16のRelationへ保存する。既存`repliesTo` chain、返信先preview、Actor Profileをhandle表示へ接続し、handle変更後もRelationを維持する。

- GitHub Repository Settings v1。Settings > External Brainからowner／repository／branchを既存UserDefaultsへ、PATを既存Keychainへ分離保存し、Token置換・確認付き削除、Repository変更時のローカルKnowledge保持警告を提供する。既存GitHub Contents clientのread-only接続確認でAuthentication／Repository／Branchとpush権限由来のDraft／Knowledge capability、分類済み接続エラー、rate limit残数を表示する。Draft／Knowledge pathはdomain定義をread-only表示する。
- Knowledge Quality & Consolidation v1。正式Knowledgeを手動ローカル解析し、正規化title／body一致、本文token類似度、tag重複からDuplicate／Similar候補を、180日未更新かつ未参照からStale候補を提示する。Quality画面でCompare、Dismiss、A/Bを並べたMerge Draft作成を行い、既存Review／Promoteへ戻す。明示操作だけでArchive／Supersedeし、対象pathを通常Retrieval indexから除外する。active KnowledgeのretrievalCount／lastRetrievedAtを記録し、単一のブラックボックスQuality Scoreは持たない。
- Knowledge Review & Promote Pipeline v1。SQLiteへDraft／provenance／Review状態／GitHub同期状態を永続化し、一覧・FTS検索・状態filter・編集可能Review・Approve／Reject・確認付きPromoteを提供する。`approved`だけを`projects/aitextapp/knowledge/`へnew-file-onlyで昇格し、成功時だけKnowledgeDocument、path、SHA、promotedAtを保存してローカルExternal Brain FTSへ即時反映する。Review操作はAI APIを呼ばず、lifecycle analyticsへsource type付きで記録する。
- Persona External Brain v2 / Knowledge Draft Pipeline。AI Reply／Persona Post／Daily Summaryから明示操作後だけAIでMarkdown Draftを生成し、decision／knowledge／memory／project-noteを選択できる。ローカルFTSで関連する既存資料を最大3件確認し、編集可能Previewで内容と安全な`drafts/`保存先をHuman Reviewした後、既存Keychain tokenでGitHubへnew-file-only保存する。AI生成とGitHub保存は別操作で、保存失敗時もDraftを保持する。保存した`status: draft`は通常RAG対象外で、正式Knowledgeへの昇格は後続の明示Review／Promote Pipelineだけが行う。Knowledge Draft生成はUsage Analyticsへ記録し、GitHub writeはAI Callへ数えない。

- External Brain Routing v1。Persona別AGENT.mdのRetrieval RouteをAI Replyだけでなく独立Persona Postにも適用し、依頼文を検索queryとして最大5チャンクを取得する。空白で単語分割できない日本語自然文はtrigramへ展開し、長い一文との完全一致を要求せず関連Knowledgeを検索する。長いheading chunkは先頭固定ではなく検索一致箇所の周辺をAIへ渡す。送信前にroute／source／heading／excerpt／最終payloadを確認でき、Usage metadataへ使用有無とchunk数を記録する。Daily SummaryにはPersona routeを適用しない。
- AI API Usage Analytics v1。設定の「AI」から使用状況Dashboardを開く。AI API Callをschema v12内の独立したローカルMetadataとして記録し、AI Reply／Daily Summary／Persona Post／Knowledge Draftを共通Recorderへ統合する。Knowledge Draftはsource typeも保持する。Persona／Feature／Provider／Model別件数、成功率、Error、Latency、日別推移を集計し、External Brain使用有無・取得chunk数も保持する。token usageはproviderから取得できる場合だけ実測保存し、現状はnilのまま文字数を常時記録する。prompt／response／Thought／External Brain本文はUsage DBへ保存せず、Telemetry保存失敗は既存AI機能を失敗させない。
- Persona External Brain v1。単一GitHub RepositoryとPersona別AGENT.md／Retrieval Routeを使い、MarkdownをApplication SupportへSHA差分同期してheading単位のSQLite FTS5 indexから最大5チャンクを取得する。AI Reply送信前Previewで資料と最終payloadを確認できる。GitHubはread-only、tokenはKeychain保存で、障害時はcacheまたはExternal Brainなしで返信を継続する。

- `TabView`によるHome／Mentions／Search／Insights／Profileの5タブ。各タブは独立した`NavigationStack`を持ち、Home右上の鉛筆から投稿Composerを開き、隣のフィルターから投稿者単位でTimelineを絞り込む。MentionsはHuman／AI Persona宛てのMention・Reply、Searchは本文検索、InsightsはDaily Summary／Analytics、Profileは投稿一覧を持たない共通Actor Profile UIを表示する。SettingsはProfile右上へ集約する。
- ローカルの単一人間Persona基盤。SQLite schema v6の`personas`／`thought_authors`で既存・新規Thoughtを固定のデフォルト人間へ紐づけ、表示名と512px以下へ正方形化したJPEGアイコンをSQLite内へ保存する。
- Timelineの投稿者名・丸型アイコン表示と、写真選択／削除／表示名編集を行うプロフィール画面。未設定時は標準人物アイコンを表示し、プロフィール変更を既存Thoughtへ一括反映する。
- 複数AI Personaの作成・編集・無効化UIと、投稿ごとの実Persona表示。任意Persona IDでThoughtを原子的に保存でき、通信はユーザーの明示操作時だけ行う。
- AI Personaごとの役割・指示設定と、明示的な「投稿を依頼」導線。ユーザー依頼と最終payloadをプレビューし、確定後だけFirebase AI Logicを呼び、140文字以内の成功応答だけをAI Persona名義でTimelineへ保存する。
- SQLite schema v7の`ai_persona_configurations`／`ai_post_generations`。AI設定と生成来歴をThought本文から分離し、Thought・投稿者・provider／model／prompt version／ユーザー依頼を同一transactionで保存する。自動投稿は行わない。
- AI Personaへの単一メンションv1。Timeline ComposerでactiveなAIを選択し、schema v8の`thought_mentions`へ本文と同じtransactionでPersona IDを保存する。Timelineは現在のPersona名を`@名前`で表示し、メンションだけではAI通信を開始しない。
- メンション付きThoughtから明示的に依頼するAI返信v1。送信前にAI、対象Thought、役割、指示、最終payload、provider／modelを確認し、対象Thoughtだけを送る。成功した140文字以内の応答はAI名義Thought、`repliesTo` Relation、返信先を含む生成来歴としてschema v9へatomic保存する。同一Thoughtへの複数返信を許可し、Detailで返信一覧を確認できる。
- AI Reply Context v1。対象Thoughtから`repliesTo`だけを遡る直近最大5件を、Human／AI投稿者付き・古い順で送信前previewとpromptへ含める。削除済み本文、Continuation、重複、cycleを除外し、送信直前のContext再取得でThought・Relation・投稿者・対象が変わっていればAIを呼ばない。Mentionだけでは通信しない。AI Replyへの人間返信は相手AIを自動メンションして同じReply chainへatomic保存する。
- AI Persona Reply v2。HumanがAI ThoughtへReplyすると相手AIをRelationから引き継ぎ、Reply Thread、Role／Instructions、同Personaの直近5発言、任意のExternal Brainで既存AI Reply promptを組み立てる。同一Human ReplyへのAI生成済みReplyはCore／SQLite双方で拒否する。Persona別`Auto Reply`はschema v17へ永続化し、既定ON。ONではHumanの@メンションを起点に承認なしで生成・atomic投稿する。AI投稿を起点にしないためAI同士の自動連鎖は行わない。
- Timeline Reply Context。Human／AI双方の返信を通常Timelineへ独立Thoughtとして表示し、`repliesTo`から取得した返信先Personaと本文を最大2行の文脈として添える。Human／AI返信の保存が成功したらDetailを閉じてTimelineへ戻り、失敗時は入力と画面を保持する。返信先本文は複製保存せず、削除済みの場合もRelationを保持してplaceholderを表示する。schema v15は`user_version`だけ進んで旧`continues`限定制約が残ったDBを実定義から検知・非破壊補修し、起動時DB health checkでその他の破損・必須schema欠落を即時検知する。
- Homeの返信表示切替。Home右上の会話ボタンで、rootに対する最初の返信は残したまま、返信への返信（2件目以降）を一時的に畳める。再度押すと全返信を表示し、投稿直後の返信は畳み中でも一時表示して投稿結果を確認できる。
- Daily Summary v3。`ThoughtRepository.fetchHumanThoughts(from:to:)`が`thought_authors`と`personas.kind`をRepository／SQLite JOINで判定し、期間内・未削除のHuman Thoughtだけを取得する。AI投稿／自動返信／返信／フリートーク本文はprompt・件数・タグ・テーマ・思考の流れ・Continuation集計から完全に除外する。Mention先は判定に影響しない。要約済みの過去日も「この日を再生成」から最新promptで送信前Previewへ進み、新しい生成が成功した場合だけ日付単位で旧Summaryを置き換える。既存v1／v2 Summaryと`aiInteractions`は削除せず後方互換で読めるが、新規v3生成では`aiInteractions`を要求・保存しない。AI側の活動は将来の独立したAI Summaryの責務とする。
- サマリー閲覧専用ページ。振り返りから生成済みサマリーを種別・対象日・概要付きで新しい順に確認でき、詳細には再生成・外部脳保存・タグ追加などの変更操作を置かない。現時点の種別はデイリーだけだが、生成カレンダーと閲覧導線を分離して将来の週次／月次追加先を明確にする。
- AI Tag Suggestions。Daily SummaryがHuman Thoughtのprompt連番単位でタグ名・理由を提案し、生成後に有効なHuman indexだけを内部Thought IDへ解決する。確定タグ分析とは分離し、不正indexとAI Thought候補を除外する。Detailの「追加」を押した場合だけ既存`ThoughtTagRepository`の独立transactionで確定タグにする。
- 振り返り導線をDaily Summaryへ統一。TimelineのHistory Review入口と画面、旧期間AI要約UIを外し、既存の`review_summaries`はデータ互換のためSQLite内に保持する。
- Timelineトップバーの独立タグ一覧ボタンを外し、Thoughtに付いたタグは`tag.fill`と名前を組み合わせて文脈内で識別しやすく表示する。

- 端末Calendar／timezoneの1日境界で明示生成するDaily Summary v3。月カレンダーで要約済み／Human Thoughtあり未要約／Human Thoughtなしと今日を区別し、過去日の日別詳細、Human Thoughtだけの送信前preview、構造化結果の表示と再読込を提供する。
- SQLite schema v5の`daily_summaries`。Thought原文と分離した1日1件の正式Summaryとして構造化結果と生成メタデータを保存し、AI候補からタグ／Thought／Continuationを自動変更しない。
- タグチップ、タグ追加、タグ編集ボタンの操作領域を44pt以上へ拡大。

- 140文字制限、空白除去、空投稿防止を備えた投稿Composer。
- 新しい順のTimeline、投稿日時、削除確認と即時反映。
- UUIDと作成・更新・削除日時を持つThought原文モデル。
- Application Support配下のSQLiteを正本にしたローカル保存、query順序、ソフトデリート。
- 既存JSONをtransaction内で検証して一度だけ取り込む、再実行可能なmigration。
- `PRAGMA user_version`によるschema version管理（現在v19）。v14は実カラム補修、v15はReply Relation制約補修、v16はActor handle／Mention snapshot、v17はAI Persona Auto Reply、v18は旧`account_id`単独UNIQUE制約の非破壊補修、v19はAI Persona providerを非破壊追加する。
- Home右上の鉛筆アイコンから開き、入力へ自動focusする投稿Composer。投稿操作はNavigation bar右上に置き、空入力や140文字超過時は無効化する。
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
- `createdAt`昇順の安定したReview表示、Thought Detailへの遷移、Continuation件数の軽量表示。
- SQLiteの日付範囲query（開始inclusive／終了exclusive）とRelation件数の一括query。
- Files／iCloud Driveのユーザー選択フォルダへSQLite Online Backup APIの完全snapshotを保存する外部災害復旧バックアップ。
- Thought原文と分離したSQLite schema v3の`review_summaries`と、通信／保存を抽象化した要約use case。
- Firebase Apple SDK 12.17.0以降の`FirebaseAILogic`／`FirebaseAppCheck`／`FirebaseCore`依存と、Gemini／OpenAIをrequest単位で選ぶcomposition root。
- Daily Summaryの確定promptをOpenAI `gpt-5.6-luna`へmediumで送り、成功時だけ既存SQLite保存へ進む実クライアント。Gemini transportはPersona系と選択時のKnowledge Draftに利用する。
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
- Timelineから開くローカル分析画面。今日／過去7日／過去30日、活動日数、1活動日平均、30日の日別カレンダー（件数・濃淡・今日の枠線）、曜日別・時間帯別分布、上位5タグ、Continuationを持つThought数を表示。
- typed分析model、端末Calendarから30日の日／時間帯境界を構築する`LoadThoughtAnalytics`、CRUDから分離したread-only `ThoughtAnalyticsRepository`。
- Daily Summary v3: Calendar日境界、RepositoryでのHuman限定取得、Humanタグ／Relation／時間帯分析、OpenAI `medium`の構造化応答、既存Summary互換の独立SQLite保存、月間カレンダー、日別詳細、Timeline統合。AI Summaryは未実装で別責務。
- SQLiteの境界CTE＋`COUNT`／`GROUP BY`、タグJOIN集計、activeな期間内親子のRelation集計。原文全件をViewへ取得せず、deleted／期間外ThoughtをSQLで除外する。

## 未実装

- Release用App Attest providerのFirebase Console登録と実機通信。Debug Providerは実機で実通信とSQLite保存を確認済み。
- AI分類など要約以外の派生情報、クラウド同期、アカウント、その他の外部連携。
- CI/CD、配布用の署名・bundle identifier設定。

## AI要約：Release App Attest確認待ち

ロードマップ5-Aはコード実装とDebug ProviderでのFirebase実接続まで確認済みです。Release App Attestの確認が残っています。

1. 完了: Firebase Apple SDK 12.18.0をresolveし、3製品を含むDebug／Release buildを確認する。
2. 完了: Git管理外の`GoogleService-Info.plist`を存在時だけapp bundleへcopyし、bundle identifier一致を確認する。
3. 完了: Debug ProviderのDebug tokenをFirebase Consoleへ登録し、Debug buildの実機でApp Check交換を通す。
4. 完了: Gemini実APIでAI要約を実行する。
5. 完了: `gemini-3.7-flash`で実応答を確認する。
6. 完了: 実機SQLiteにprovider、model、対象件数を持つ要約が保存されることを確認する。
7. Release buildとApp Attestで実通信を確認する。
8. 問題がなければロードマップ5-Aを完了へ変更し、結果を踏まえて5-Bの仕様を再評価する。

再開指示は「AI要約の続きを進める」「Gemini連携を再開する」などを目印とし、この地点から再開します。それまではAI機能設定画面や新たなFirebase依存機能を先行実装せず、別分野の開発を優先します。

## 既知の問題

- iPhone SE (3rd generation, iOS 17.4)のbuildとXCUITestは確認済みですが、Light／Dark Modeの手動目視確認は未実施です。
- 破損した移行元JSONは自動復旧せず、SQLiteへの移行を中止してエラー表示し、原本を保持します。
- XCUITestは投稿・削除、Continuationの主要フローをiPhone SE Simulatorで確認済みです。Daily Summary統一後のUI回帰確認が必要です。
- App iconの実画像は未設定です。
- Phase 3-AのSwift Testing、Xcode build、XCUITest、Light／Dark Mode、Dynamic Type、VoiceOverの実機／Simulator確認はWindows環境のため未実行です。
- Phase 3-Bのschema v4 migration、タグunit test、XCUITest、Light／Dark Mode、Dynamic Type、VoiceOverの実機／Simulator確認はWindows環境のため未実行です。
- Phase 3-Cの期間境界、期間＋タグquery、Review概要・日別表示、AI対象差、XCUITest、各アクセシビリティ表示はWindows環境のため未実行です。
- Phase 3-DのSwift Testing、SQLite集計SQL、timezone／時間帯境界、分析画面XCUITest、小型iPhoneでのバー表示、Dynamic Type／Dark Mode／VoiceOverはWindows環境のため未実行です。

## 次に行うこと

### Xcode環境が利用可能になったら行う検証

未実行項目と実施順はRepository直下の`MAC_VALIDATION.md`へ集約する。Windowsで機能を追加した場合は、Mac固有のcompile／Simulator／実機／署名確認を同ファイルへ追記してから完了とする。

### 次の実装候補

#### 非AIロードマップ

1. Phase 3-A: Thought検索 v1 — コード実装済み／Mac確認待ち。
2. Phase 3-B: Thoughtタグ v1 — コード実装済み／Mac確認待ち。
3. Phase 3-C: History Review強化 v1 — 撤回。振り返り導線はDaily Summaryへ統一済み。
4. Phase 3-E: Quick Capture／Widget — 通常投稿Composerとの重複を理由に削除済み。将来、未整理メモ用Inboxなど用途が明確に異なる場合は別機能として再設計する。
5. Phase 3-D: ローカル分析 v1 — コード実装済み／Mac確認待ち。SQLite集計基盤と直近30日の小さな分析画面まで。

Phase 3の機能追加は一度止め、次はMac検証を最優先する。3-A〜3-Dにcompile／Simulator未確認が蓄積しているためである。検証と実利用後、分析画面で具体的な意思決定が不足する場合だけ分析v2を検討する。根拠がなければPhase 4の別テーマを決める。

#### AIロードマップ

1. 完了: AI要約履歴画面 — 同期間の過去要約を新しい順に表示し、生成日時、対象件数、生成元を確認可能。
2. 完了: AI要約の削除 — 要約ID単位の確認付き削除。Thought原文、別期間、他要約には影響しない。
3. 完了: 要約対象の明示プレビュー — 期間、件数、文字数、日時順本文を確認し、確定したpayloadだけを送信する。
4. 完了: 要約のExport — 選択した要約と安全なメタデータだけをMarkdown／JSONで個別共有する。
5. 5-Aコード側完了／接続確認保留: Firebase AI Logic／App Checkをcomposition rootへ接続。Console、plist、Xcode build、Simulator／実機通信は上記のとおり未確認。
6. 保留 5-B: AI機能設定画面 — 5-Aの実接続確認後に仕様を再評価する。確認前は先行実装しない。
7. 数日間の実利用後にHistory／AI要約／バックアップ／Export運用を再評価する。
