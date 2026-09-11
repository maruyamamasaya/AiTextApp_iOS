# Knowledge Review & Promote Pipeline v1

## 目的・調査結果

既存Knowledge Draft Pipeline、GitHub Contents writer、External Brain cache／FTS、AI Usage、SQLite migrationを再利用し、Human Review後だけ正式Knowledgeへ昇格する境界を追加した。External repositoryの既存Persona routeが`projects/aitextapp/`を参照するため、正式保存先は`projects/aitextapp/knowledge/`とした。

## DB・UI・GitHub・FTS

- schema v12へKnowledge Draft、Knowledge Document、lifecycle event、Draft FTSを追加。
- Draft一覧、status filter、検索、編集可能Review、Approve／Reject、Promote確認、正式Knowledge read-only一覧を追加。
- Promoteはapproved限定、GitHub new-file-onlyでSHAを取得し、成功時だけpromoted metadataと別KnowledgeDocumentを保存する。
- 正式Markdownは`status: active`としてcache／FTSへbest-effort即時反映する。Draftは引き続き除外する。
- Approve／Reject／Promote eventはsource type付きローカルanalyticsで、AI token usageを生成しない。

## Tests・Validation

- 状態遷移、直接Promote拒否、schema v12 round-trip、Draft FTS、Knowledge metadata、即時FTSとDraft除外のテストを追加。
- Windowsでは`git diff --check`とconflict marker確認のみ実施。Swift／Xcode／GitHub実通信は`MAC_VALIDATION.md`へ記録。

## 次フェーズ候補

- 正式Knowledgeの改訂／supersede、DraftのGitHub側review status同期、repository構造の設定可能化。
