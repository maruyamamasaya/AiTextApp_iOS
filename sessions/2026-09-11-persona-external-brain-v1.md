# Persona External Brain v1

- 単一GitHub Repository設定とPersona別のenabled／AGENT.md path／最大参照数を追加。
- GitHub read-only差分同期、Keychain token、Application Supportのfiles／manifest／FTS5 indexを追加。
- AGENT.md、front matter、heading chunk、draft除外、path traversal拒否を追加。
- route、project、active、high、relevance、updated順の検索と最大5件を追加。
- AI Reply PreviewへAGENT、route、source、heading、excerpt、最終payloadを追加し、資料を命令ではなく参考情報として境界化。
- Parser、Markdown、sync、offline cache、retrieval、0件、prompt境界のテストを追加。

Windows環境にSwift toolchain／Xcodeがないため`swift test`とiOS buildは未実行。Macで実行する。
