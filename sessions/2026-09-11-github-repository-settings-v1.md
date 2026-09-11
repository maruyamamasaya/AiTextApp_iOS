# GitHub Repository Settings v1

## 現状調査

既存`ExternalBrainManager`がrepository設定をUserDefaults、`ExternalBrainTokenStore`がPATをKeychainへ保存し、Read、sync、Draft保存、Promoteが同じ設定を利用していた。新しい設定系統やSQLite migrationは不要と判断した。

## 実装

- SettingsのExternal Brain画面でowner、repository、branchを編集・保存可能にした。
- PATのマスク入力、入力中Show／Hide、Keychainへの置換保存、確認付き削除を追加した。保存済みPAT自体はUIへ読み戻さない。
- Repository変更時、ローカルDraft／Knowledgeがあれば保持方針と今後の保存先変更を確認する。
- 既存GitHub remoteへGETだけのTest Connectionを追加し、Authentication、Repository、Branch、push権限由来のWrite Drafts／Write Knowledge、rate limit残数を表示する。
- 401、repository 404、branch 404、403 access denied、403 rate limit、networkを区別した。
- Draft／Knowledge directoryをdomainのpath定義から表示し、UI hardcodeを避けた。
- schema versionは13のまま変更していない。

## Tests

設定modelのsecret非保持とround-trip、path正本、HTTP error分類をSwift Testingへ追加した。Windowsでは`git diff --check`とconflict marker検査を行う。

## 未検証項目

Swift／Xcodeを利用できないWindows環境のため、compile、Swift Testing、Keychain、Settings UI、Repository変更UI、GitHub実通信、再起動後復元は`MAC_VALIDATION.md`へ追加した。

## 次フェーズ候補

Mac上のURLProtocol integration testと実Repositoryでfine-grained PATの権限組合せを確認し、必要なら接続履歴の非secret診断表示を追加する。
