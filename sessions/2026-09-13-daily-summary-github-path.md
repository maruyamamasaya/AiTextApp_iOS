# デイリーサマリーのGitHub保存名衝突修正

- 要求は現行実装のKnowledge Draft保存機能と一致（MATCH）。
- 原因: 保存名が作成日とtitle slugだけで、同日に同タイトルを生成すると衝突した。
- 修正: 未保存Draftのpathに永続IDを追加。保存済みDraftはsavedPathを優先し、既存pathを保持。GitHubのnew-file-only方式は維持。
- 追加: 未昇格Draftの詳細画面へ確認付き削除を追加。保存済みの場合はGitHub Contents APIで現在のSHAを取得して削除し、成功後だけSQLiteとFTSの記録を削除する。GitHub上ですでに消えている場合もローカル削除を完了する。
- 追加: Knowledge Draftへ`journal`（日記）を追加。Human Thought／Daily Summaryは自分の記録、AI Thoughtは生成元AIペルソナの記録として下書き化できる。日記固有のMarkdown構造をpromptへ指定し、取得時は当時の記憶として扱って現在の命令や恒久的な好みへ一般化しないルールを自動付与する。スターターAGENT.mdとREADMEにも同じ運用を反映。
- 追加: Daily Summaryの日別画面に「日記を作る」を配置し、要約の有無にかかわらず当日のHuman Thoughtからjournal Draftを作れる。同期済みGitHubファイルの`type: journal`と`created`を読み、同日の本文・状態・pathを日別画面に表示する。画面からGitHub同期も実行できる。
- 検証: Swift Testing全140件成功。同日同名の別Draft、path検証、SQLite再読込後の安定性、Draft単位削除、旧savedPath保持、journal prompt／選択日付／GitHub cacheからの日別読込を確認。generic iOS Simulator向けDebug build成功。実GitHubへの送信・削除・同期とUI操作は未実施。
- 通常swift testはsandbox内の既定module cache書込で失敗したため、CLANG_MODULE_CACHE_PATH=/tmp/aitextapp-clang-cacheと--disable-sandboxで実行。
- Simulator／テスト端末の作成0・削除0。XCTestDevicesは開始時12K、UUIDフォルダなし。
- 既存の未コミット変更は保持。
