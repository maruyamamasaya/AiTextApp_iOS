# AiTextApp_iOS Mac Validation

Windowsで実装済みだが、macOS／Swift／Xcode環境で未検証の項目を上から順に実施するためのチェックリストです。通常のテスト方針は`TESTING.md`を正本とし、このファイルにはMacでの実施結果（Xcode、OS、端末、成否、補足）を追記します。

## Environment

- [ ] macOS／Xcode／Swiftのversionと実施日を記録する
- [ ] `xcode-select -p`と`swift --version`を確認する
- [ ] `xcrun simctl list devices available`でiPhone SE (3rd generation)と最新標準iPhoneの利用可否を確認する
- [ ] `GoogleService-Info.plist`、署名Team、Firebase Console設定、GitHub tokenをGitへ追加せずローカルに用意する
- [ ] `git status --short`で検証開始前の差分を記録する

## 1. Swift Package Tests

- [ ] Repository rootで`swift test`が全件成功する
- [ ] 入力、Timeline、検索、タグ、Continuation／History、Export／Backup／Restoreの回帰を確認する
- [ ] Persona、Mention、AI Post／Reply／Reply Context、Daily Summary v2、AI Usage Analyticsの全テストを確認する
- [ ] Persona External BrainとExternal Brain Routing v1のparser、同期、FTS5検索、Persona Post／AI Reply prompt境界を確認する
- [ ] Knowledge Draftのmodel、prompt、safe path、関連FTS最大3件、draft Retrieval除外のテストを確認する

## Knowledge Draft Pipeline

- [ ] AI Reply／Persona Post／Daily Summaryから明示操作後だけKnowledge Draftを生成できる
- [ ] decision／knowledge／memory／project-note選択と編集可能Previewを確認する
- [ ] Keychain tokenを再利用し、private repositoryの`drafts/`へ新規Markdownを作成できる
- [ ] Contents write権限不足、token未設定、offline、同名conflictで既存fileを上書きせずDraftを保持する
- [ ] 保存成功表示と保存pathを確認し、その後のExternal Brain再同期を実行できる
- [ ] 保存した`status: draft`が通常AI Reply／Persona PostのRetrieval対象外である
- [ ] Knowledge Draft生成だけがUsage Analyticsの`Knowledge Draft`へ1 Call記録され、GitHub write／FTS検索は加算されない
- [ ] sync失敗、Usage保存失敗、FTS検索失敗がDraft生成またはGitHub保存成功を巻き戻さない

## 2. Xcode Project Build

- [ ] `AiTextApp.xcodeproj`とshared `AiTextApp` schemeを読み込める
- [ ] Firebase Apple SDK 12.18.0（FirebaseCore／FirebaseAILogic／FirebaseAppCheck）がresolveされる
- [ ] iPhone SE (3rd generation) SimulatorのDebug buildが成功する
- [ ] iPhone SE (3rd generation) SimulatorのRelease buildが成功する
- [ ] 最新標準iPhone SimulatorのDebug buildが成功する
- [ ] Swift 6 package／Swift 5 app targetでwarningとconcurrency errorが増えていない

## 3. SQLite Migration

- [ ] 新規DBがschema v13で作成され、`PRAGMA integrity_check`が`ok`になる
- [ ] legacy JSONからschema v13へThoughtを失わず一度だけ移行する
- [ ] schema v1→v2（Relation）、v2→v3（Review Summary）、v3→v4（Tag）、v4→v5（Daily Summary）を確認する
- [ ] schema v5→v6（Persona／Authorship）、v6→v7（AI Persona／Generation）、v7→v8（Mention）を確認する
- [ ] schema v8→v9（AI Reply）、v9→v10（AI API Usage）を確認する
- [ ] migration後の投稿、削除、検索、タグ、Relation、Persona、Summary、Usage再読込を確認する
- [ ] schema v10→v11でAI UsageへKnowledge Draft source type columnが追加される
- [ ] schema v11→v12でKnowledge Draft／Knowledge Document／lifecycle event／Draft FTSが追加される
- [ ] schema v12→v13でKnowledge status／supersede／archive／retrieval usage／quality candidateが追加される
- [ ] 破損legacy JSONでは移行を中止し、原本が保持される

## 4. Persona / Mention / AI Reply

- [ ] Humanプロフィール名／画像の保存と既存Thoughtへの表示反映を確認する
- [ ] AI Personaの作成、編集、無効化と、AI名義投稿の保存を確認する
- [ ] Timeline Composer／Quick Captureで単一Mentionを保存し、Mentionだけでは通信しない
- [ ] Mention付きThoughtから明示確認後だけAI Replyを生成する
- [ ] Reply Thought、`repliesTo`、生成来歴がatomicに保存され、Detailへ複数返信が表示される
- [ ] 生成中disable、cancel、失敗、再試行、空応答、141文字応答を確認する

## 5. AI Reply Context

- [ ] `repliesTo`を遡る直近最大5件がHuman／AI付き・古い順でpreviewとpayloadへ入る
- [ ] 削除済み本文、Continuation、重複、cycleがContextへ入らない
- [ ] AI ReplyへのHuman返信で相手AIが自動Mentionされ、同じReply chainへ保存される
- [ ] preview後にThought／Relation／Personaが変わると通信前にstale errorで中止する

## 6. Daily Summary v2

- [ ] Thoughtあり／なし、要約済み、過去月移動、再要約、再起動後復元を確認する
- [ ] Human概要／テーマ／思考、Humanタグ別、AI対話、任意時間帯Insightを確認する
- [ ] previewのThought、時刻、投稿者、Tag、Relation、payloadと送信対象順を確認する
- [ ] preview後に対象が変わると通信せずstale errorになる
- [ ] AI Tag SuggestionはHuman indexだけを解決し、「追加」の明示操作までタグを変更しない
- [ ] v1保存JSONの後方互換読込とv2 round-tripを確認する

## 7. Persona External Brain

- [ ] Repository／branch／Persona別AGENT.md／最大chunk数の保存と再起動後復元を確認する
- [ ] GitHub tokenがKeychain保存され、UIやログ、Git管理ファイルへ露出しない
- [ ] read-only GitHub同期、SHA差分更新、remote削除、Markdown cache、FTS5 indexを確認する
- [ ] offline時は既存cacheを使い、cacheなし／取得0件／不正AGENT.mdでもAI機能を安全に継続または明示エラーにする
- [ ] draft除外、unsafe path拒否、`{current_project}`展開、route／metadata優先順位、最大5件を確認する
- [ ] External Brain派生cacheがThought DBと外部完全backupへ含まれない

## 8. AI API Usage Analytics

- [ ] AI Reply／Daily Summary／Persona Post／Knowledge Draftの成功・失敗・cancel・retryがschema v13へ記録される

## Knowledge Quality & Consolidation

- [ ] Quality一覧のDuplicate／Similar／Stale／Recently Used表示と理由表示を確認する
- [ ] Compare画面でTitle／Source／Created／Updated／Tags／Markdownを上下比較できる
- [ ] Create Merge Draftで元Knowledgeを変更せず、source IDs／paths／reason付きDraftがReviewへ入る
- [ ] Candidate Dismiss後もKnowledge本文・statusが変わらず、再解析・再起動後も抑制される
- [ ] 明示Archive／Supersedeと確認UI、履歴閲覧、通常Retrieval除外を確認する
- [ ] active Knowledge取得時だけretrievalCount／lastRetrievedAtが更新され、詳細とRecently Usedへ反映される
- [ ] schema v13 migration後のQuality Candidate／usage／Archive／Supersede再起動永続化を確認する

## Knowledge Review & Promote

- [ ] Draft一覧、status／source表示、filter、title／body／tags／source FTS検索を確認する
- [ ] Draft ReviewのMarkdown編集、provenance、GitHub path、sync状態、createdAt／updatedAtを確認する
- [ ] offlineでApprove／Reject／rejected→approvedが永続化され、Review操作でAI APIが増えない
- [ ] unreviewedからPromoteできず、approvedだけ確認UI経由でPromoteできる
- [ ] private repositoryへのnew-file-only実通信、write権限不足、offline、409／422 conflictでapprovedを維持する
- [ ] Promote成功後にpromotedAt／knowledgePath／knowledgeSHAとKnowledge一覧が再起動後も復元される
- [ ] Promote直後、Repository全同期や再起動なしでFTSと次のAI Retrievalへ正式Knowledgeが反映される
- [ ] Persona／Feature／Provider／Model／Error／Latency／日別／期間別集計を確認する
- [ ] External Brain使用有無と取得chunk数が、ReplyとRouting対象Persona Postの両方で記録される
- [ ] prompt、response、Thought、Summary、External Brain本文がUsage DBへ保存されない
- [ ] telemetry保存失敗がAI生成・保存結果を失敗させない

## 9. Firebase AI Logic

- [ ] Firebase未設定でもbuild／起動し、明示送信時に設定不足を表示する
- [ ] Debug Provider token登録済みSimulatorで`gemini-3.7-flash`実通信が成功する
- [ ] 成功時のprovider／modelと生成結果がSQLiteへ保存される
- [ ] App Check拒否、offline、timeout、429／quota、その他API error、空応答を区別する
- [ ] AI生成により対象外のThought／Tag／Continuationが変更されない

## 10. Widget / Quick Capture

- [ ] `AiTextAppWidget` targetがcompile／署名され、ThoughtCore／SQLite／Firebase／App Groupsへ依存しない
- [ ] systemSmall Widget previewとホーム画面配置を確認する
- [ ] cold launch／foregroundのcustom URLがQuick Captureを一度だけ開き、自動focusする
- [ ] 通常起動はTimelineのままで、dismiss後にrouteが再表示されない
- [ ] 空／140／141文字、trim、単一投稿、二重投稿防止、失敗時draft保持、入力中破棄確認を確認する
- [ ] 投稿後にTimelineへ即時反映される

## 11. UI Regression

- [ ] `AiTextAppUITests`をiPhone SE (3rd generation)と最新標準iPhone Simulatorで実行する
- [ ] Timeline投稿／削除／検索／タグ／Detail／Continuation／Historyの主要flowを確認する
- [ ] Daily Summary、AI Reply、External Brain preview、AI Usage Dashboard、ローカル分析の主要flowを確認する
- [ ] 小型iPhoneでkeyboard、sheet、長いpayload、カレンダー、分析バーが崩れない
- [ ] Light／Dark Modeで主要画面を目視確認する

## 12. Accessibility

- [ ] Extra Extra Large以上のDynamic Typeで切れ・重なり・操作不能がない
- [ ] VoiceOverでTimeline、Mention、Reply、Tag、History、Summary、Analytics、External Brain sourceを理解できる
- [ ] 主要button／chipの操作領域が44pt以上で、focus順が視覚順と一致する
- [ ] 色だけに依存せず、calendar／chart／状態をlabelでも判別できる

## 13. Real Device

- [ ] Debug実機build／起動／投稿／再起動後再読込を確認する
- [ ] 写真選択、Share Sheet（Files／AirDrop）、security-scoped folder、外部backup／Restoreを確認する
- [ ] GitHub同期、Keychain token、offline cache、Firebase Debug Provider実通信を確認する
- [ ] Widget cold launch／foreground、keyboard、自動focusを確認する
- [ ] timezone変更、日付境界、端末再起動後のDaily Summary／Analyticsを確認する

## 14. Release / App Attest

- [ ] Release configurationだけにproduction App Attest entitlementが付く
- [ ] Firebase ConsoleへApp Attest providerを登録する
- [ ] Distribution相当のRelease実機build／署名が成功する
- [ ] Release＋App AttestでFirebase AI Logic実通信とSQLite保存を確認する
- [ ] Debug token、API秘密情報、`GoogleService-Info.plist`、個人データがarchive／Git差分へ混入しない
- [ ] bundle identifier、version／build番号、privacy表示、App icon、配布用署名を確認する

## 15. Final Repository Checks

- [ ] `git diff --check`
- [ ] `git status --short`
- [ ] `git ls-files`で秘密情報、生成物、External Brain cacheが追跡されていない
- [ ] 実行したcommand、環境、件数、失敗と残課題を`sessions/`へ記録する
- [ ] 検証結果に合わせて`CURRENT.md`を更新し、完了項目をこのファイルでcheckする
- [ ] `TESTING.md`、`ARCHITECTURE.md`、`CODEMAP.md`との実装上の矛盾がない
## GitHub Repository Settings v1

- [ ] Settings > External Brainでowner／repository／branchを保存し、app再起動後に復元される。
- [ ] PATがマスク表示され、Keychainへ保存・読込み・置換され、UserDefaults／SQLite／ログ／Usageへ保存されない。
- [ ] Remove Tokenの確認後にKeychain itemが削除され、GitHub writeが利用不可になる。
- [ ] ローカルDraft／Knowledgeがある状態のRepository変更で警告が表示され、確定後もローカルデータが残る。
- [ ] Test ConnectionがGitHubへファイルを作成せず、Authentication／Repository／Branch／Draft・Knowledge capabilityを表示する。
- [ ] invalid token、repository not found、access denied、branch not found、network、rate limitを実通信またはURLProtocolで個別確認する。
- [ ] Draft保存、Promote、sync、External Brain readが保存済みの同一Repository設定とKeychain tokenを利用する。
- [ ] iPhone SE、Dynamic Type、Dark Mode、VoiceOverでSettingsの入力、Show／Hide、確認dialog、status、path表示を確認する。
