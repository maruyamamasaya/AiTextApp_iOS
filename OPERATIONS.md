# Operations

## Local Development

`AiTextApp.xcodeproj`をXcode 16以降で開き、`AiTextApp` schemeと任意のiPhone Simulatorを選んで実行します。iOS 16.0以降が対象で、外部dependencyや初回セットアップはありません。

## Local Data

初回起動時にApplication Support内の`ThoughtTimeline/thought-timeline.sqlite3`と親ディレクトリを自動作成します。同じ場所に旧`thoughts.json`があれば一度だけ取り込み、成功後もバックアップとして残します。データをリセットするにはSimulatorからアプリを削除してください。

## Build / Test

Xcodeの`AiTextApp` shared schemeでbuildします。CLIコマンドとCore testは`TESTING.md`を参照してください。

## Environment / External Services

環境変数、secret、外部サービスはありません。

## Deploy

CI/CD、配布用bundle identifier、code signing、provisioning、TestFlight/App Store設定は未構成です。

## Backup / Export

正常なDB初期化後とThoughtの書き込み後には、`thought-timeline.sqlite3.backup.1`（最新）と`.backup.2`（ひとつ前）をSQLite Online Backup APIで更新します。自動復元は行いません。DB初期化失敗時はアプリを削除せず、正本を退避してからバックアップコピーを復元します。調査なしに新規DBで上書きしないでください。

通常の持ち出しは画面右上のExportからMarkdown（人間向け）またはJSON（原文バックアップ／将来Import向け）を選び、標準Share SheetでFilesやAirDropへ保存します。Export失敗はSQLiteとComposerを変更しません。

### External Full Backup

画面右上のバックアップ管理から「バックアップ保存先を選択」を開き、Files／iCloud Drive上のユーザー管理フォルダを選びます。アプリはsecurity-scoped bookmarkを保存し、そのフォルダ内だけに`AiText Backup/latest`と`previous`を作ります。「今すぐバックアップ」はWAL利用中でも整合するSQLite Online Backup snapshotを一時directoryへ作り、manifest、サイズ、SHA-256、`PRAGMA integrity_check`、`user_version`を確認してから2世代を切り替えます。既存の無関係なファイルは削除しません。

アプリ削除前や端末移行前には、iCloud Driveなどアプリcontainer外を保存先にして「今すぐバックアップ」を実行し、成功表示と最終日時を確認してください。Application Support内の正本と`.backup.1`／`.backup.2`、保存先bookmark自体はアプリ削除で失われますが、Files上の`AiText Backup`は残ります。

### Restore

再インストール後はバックアップ管理の「バックアップから復元」から、`AiText Backup`、その親フォルダ、または`latest`／`previous`世代を選べます。アプリはmanifest形式、backup形式version、安全な相対ファイル名、symlink、SQLite存在・サイズ・SHA-256、open、integrity、schemaを検証した後にだけ確認画面を出します。「復元する」でApplication Supportのpending領域へcopy・再検証し、この時点では現DBを変更しません。

アプリを終了して次回起動すると、Repository接続前に現DBとWAL／SHMをrollback用へ退避し、pending DBを適用・再確認します。失敗時は退避した現DB一式を戻してエラーを表示します。検証または適用に失敗した場合はアプリを削除せず、外部backupの`previous`を選ぶか、バックアップフォルダの利用可能状態を確認してください。
