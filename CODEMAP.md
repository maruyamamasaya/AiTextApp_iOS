# Code Map

機能から主要コードへ到達するための索引です。網羅的なファイル一覧ではありません。実装追加時は、入口・主要処理・データ境界・関連テストと検索語を更新してください。

## 現在の入口

Files:
- `README.md` — 人間向け概要と文書への入口。
- `CURRENT.md` — 実装済み／未実装と次の作業。
- `AGENTS.md` — AI作業規約。

Search keywords:
- `現在の状態`
- `実装済み`
- `未実装`

## Application Entry / UI

Files: なし。Swiftソース、Xcode project/workspaceは未登録です。

実装後の候補検索語:
- `@main`
- `App`
- `Scene`
- `View`
- `UIViewController`

## Text Memo Feature

Files: なし。「X風のテキストメモアプリ」という概要だけが `README.md` にあります。

実装後の候補検索語:
- `Memo`
- `Note`
- `Text`
- `Timeline`
- `Post`

## API / External Services

Files: なし。API path、HTTP client、外部SDK、サービス設定は未登録です。

実装後の候補検索語:
- `URLSession`
- `URLRequest`
- `https://`
- `/api/`
- `APIKey`

## Database / Persistence

Files: なし。DBテーブル、model、repository、migrationは未登録です。

実装後の候補検索語:
- `SwiftData`
- `CoreData`
- `ModelContainer`
- `UserDefaults`
- `Repository`

## Authentication

Files: なし。認証要件も未確認です。

実装後の候補検索語:
- `AuthenticationServices`
- `ASAuthorization`
- `login`
- `session`
- `accessToken`

## Configuration / CI / Deployment

Files: なし。project、scheme、`.xcconfig`、workflow、配布設定は未登録です。

Search keywords:
- `*.xcodeproj`
- `*.xcworkspace`
- `Package.swift`
- `Info.plist`
- `*.xcconfig`
- `workflow`

## Tests

Files: なし。詳細は `TESTING.md` を参照してください。

実装後の候補検索語:
- `XCTestCase`
- `@Test`
- `Tests`
- `UITests`
- `test`

## 横断検索のレシピ

```bash
# 追跡対象と主要設定を把握
git ls-files
rg --files -g '*.swift' -g '*.xcodeproj/**' -g 'Package.swift'

# シンボル、経路、設定から探索
rg 'TypeName|functionName'
rg '/api/|URLSession|URLRequest'
rg 'ProcessInfo|Info\.plist|xcconfig|API_KEY'
rg 'TODO|FIXME'

# テストとの対応を探す
rg 'XCTestCase|@Test|FeatureName' --glob '*Test*' --glob '*.swift'
```

検索語が判明しているときは `rg`、Git追跡ファイルだけなら `git grep`、型の参照・呼び出し関係にはXcode/IDEのシンボル検索やlanguage serverを使ってください。
