# Operations

## Local Development

`AiTextApp.xcodeproj`をFirebase AI Logicが要求するXcode 26.2以降で開き、`AiTextApp` schemeと任意のiPhone Simulatorを選んで実行します。iOS 16.0以降が対象です。通常起動はFirebaseクライアントを使い、Firebase未設定時は外部送信せず設定エラーを表示します。UIテストはMemory repositoryとMock AIクライアントを使います。

## Local Data

初回起動時にApplication Support内の`ThoughtTimeline/thought-timeline.sqlite3`と親ディレクトリを自動作成します。同じ場所に旧`thoughts.json`があれば一度だけ取り込み、成功後もバックアップとして残します。データをリセットするにはSimulatorからアプリを削除してください。

## Build / Test

Xcodeの`AiTextApp` shared schemeでbuildします。CLIコマンドとCore testは`TESTING.md`を参照してください。

## Environment / External Services

### Persona External Brain

設定 > External Brainで単一GitHub Repositoryのowner、repository、branchとread-onlyのfine-grained tokenを設定し、「今すぐ同期」を実行します。tokenはKeychainにのみ保存され、SQLite、Export、backup、ログへ含めません。Persona編集でExternal BrainをONにし、同Repository内のAGENT.md pathと最大参照数を指定します。cacheは`Application Support/ExternalBrain`配下の派生データで、同期失敗時は前回cacheを使い、cacheがなければExternal BrainなしでAI Replyを続行します。

Firebase Apple SDKはSwift Package Managerで12.17.0以降を指定し、app targetへ`FirebaseCore`、`FirebaseAILogic`、`FirebaseAppCheck`をリンクします。APIキーをSwiftコードへ追加しません。

### Firebase AI Logic / App Check接続

1. Firebase Consoleで実際のbundle identifierを持つiOS appを登録し、Firebase AI LogicのGet startedからGemini Developer APIを有効化する。
2. Consoleから`GoogleService-Info.plist`を取得してリポジトリrootへ配置する。app targetの`Copy Optional Firebase Configuration` build phaseが、存在する場合だけapp bundleへcopyする。このファイルは`.gitignore`対象で、各開発環境へ安全に配布する。
3. Xcodeでpackageをresolveし、`FirebaseCore`、`FirebaseAILogic`、`FirebaseAppCheck`がapp targetへリンクされていることを確認する。
4. Debug buildを起動する。Debug configurationはApp Attest entitlementを持たず、Personal Teamでも署名可能にする。`AppCheckDebugProviderFactory`が出力するDebug tokenをFirebase ConsoleのApp Check > Manage debug tokensへ登録する。tokenはScheme、ソース、文書へ記録・コミットしない。
5. Release buildは`AppAttestProviderFactory`と`AiTextApp.entitlements`のproduction App Attest環境を使う。ConsoleでApp Attestを登録し、実機で成功を確認してからenforcementを段階的に有効化する。
6. Daily Summaryでプレビュー内容を確認して明示送信し、保存された要約のproviderが`firebase-ai-logic`、modelが`gemini-3.7-flash`であることを確認する。

`GoogleService-Info.plist`がない場合は起動を継続し、AI送信時に未設定エラーを表示します。App Check、429／quota、network、その他API、空応答はユーザー向けの別エラーへ変換します。Firebase ConsoleのenforcementはDebug tokenと実機App Attestの確認後に有効化してください。

## Deploy

CI/CD、配布用bundle identifier、code signing、provisioning、TestFlight/App Store設定は未構成です。

## Backup / Export

正常なDB初期化後とThoughtの書き込み後には、`thought-timeline.sqlite3.backup.1`（最新）と`.backup.2`（ひとつ前）をSQLite Online Backup APIで更新します。自動復元は行いません。DB初期化失敗時はアプリを削除せず、正本を退避してからバックアップコピーを復元します。調査なしに新規DBで上書きしないでください。

通常の持ち出しは画面右上のExportからMarkdown（人間向け）またはJSON（原文バックアップ／将来Import向け）を選び、標準Share SheetでFilesやAirDropへ保存します。Export失敗はSQLiteとComposerを変更しません。

Daily Summaryはアプリ内の日別振り返りとしてSQLiteと外部完全バックアップに含まれます。旧History Reviewの期間要約Export導線は現在提供しません。

### External Full Backup

画面右上のバックアップ管理から「バックアップ保存先を選択」を開き、Files／iCloud Drive上のユーザー管理フォルダを選びます。アプリはsecurity-scoped bookmarkを保存し、そのフォルダ内だけに`AiText Backup/latest`と`previous`を作ります。「今すぐバックアップ」はWAL利用中でも整合するSQLite Online Backup snapshotを一時directoryへ作り、manifest、サイズ、SHA-256、`PRAGMA integrity_check`、`user_version`を確認してから2世代を切り替えます。既存の無関係なファイルは削除しません。

アプリ削除前や端末移行前には、iCloud Driveなどアプリcontainer外を保存先にして「今すぐバックアップ」を実行し、成功表示と最終日時を確認してください。Application Support内の正本と`.backup.1`／`.backup.2`、保存先bookmark自体はアプリ削除で失われますが、Files上の`AiText Backup`は残ります。

### Restore

再インストール後はバックアップ管理の「バックアップから復元」から、`AiText Backup`、その親フォルダ、または`latest`／`previous`世代を選べます。アプリはmanifest形式、backup形式version、安全な相対ファイル名、symlink、SQLite存在・サイズ・SHA-256、open、integrity、schemaを検証した後にだけ確認画面を出します。「復元する」でApplication Supportのpending領域へcopy・再検証し、この時点では現DBを変更しません。

アプリを終了して次回起動すると、Repository接続前に現DBとWAL／SHMをrollback用へ退避し、pending DBを適用・再確認します。失敗時は退避した現DB一式を戻してエラーを表示します。検証または適用に失敗した場合はアプリを削除せず、外部backupの`previous`を選ぶか、バックアップフォルダの利用可能状態を確認してください。
