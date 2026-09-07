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
