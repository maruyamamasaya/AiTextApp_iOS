# Operations

## Local Development

`AiTextApp.xcodeproj`をXcode 16以降で開き、`AiTextApp` schemeと任意のiPhone Simulatorを選んで実行します。iOS 16.0以降が対象で、外部dependencyや初回セットアップはありません。

## Local Data

初回投稿時にApplication Support内の`ThoughtTimeline/thoughts.json`と親ディレクトリを自動作成します。データをリセットするにはSimulatorからアプリを削除してください。

## Build / Test

Xcodeの`AiTextApp` shared schemeでbuildします。CLIコマンドとCore testは`TESTING.md`を参照してください。

## Environment / External Services

環境変数、secret、外部サービスはありません。

## Deploy

CI/CD、配布用bundle identifier、code signing、provisioning、TestFlight/App Store設定は未構成です。
