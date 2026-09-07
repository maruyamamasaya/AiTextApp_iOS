# Operations

## Local Development

実行可能なアプリケーションはまだありません。リポジトリはGitで取得できますが、Xcodeで開くproject/workspaceや起動コマンドは存在しません。

実装開始時には、必要なXcode/Swiftのバージョン、project/workspace、scheme、simulator destination、初回セットアップをここへ記録してください。

## Environment Variables / Configuration

環境変数、`.xcconfig`、plist設定、secret管理はありません。必要になった場合は変数名・用途・必須/任意・安全な入手方法だけを記録し、実際のtoken、password、証明書、秘密鍵、production値はコミットしないでください。

## Database Setup

DBやローカル永続化は未実装で、セットアップはありません。

## External Services

外部サービスは設定されていません。X風という説明は、Xサービスとの連携を意味するとは確認できません。

## Build

ビルド構成がないため実行できません。追加後は `TESTING.md` に検証コマンド、本書に開発者向け起動手順と必要設定を記載します。

## Deploy

CI/CD、code signing、provisioning、bundle identifier、TestFlight/App Store配布設定はありません。配布先も未確認です。

## Troubleshooting

- 開くprojectが見つからない: 現在は未登録で、正常な既知状態です。`CURRENT.md` を確認してください。
- ビルドコマンドが分からない: 現在は実行できません。projectとscheme追加後に本書と `TESTING.md` を更新してください。
- 文書と実装が違う: コード・設定・テストを調査し、事実と意図を区別したうえで関連文書を更新してください。
