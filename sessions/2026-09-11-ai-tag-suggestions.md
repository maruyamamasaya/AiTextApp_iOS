# AI Tag Suggestions

- `DailySummaryThoughtTagSuggestion`を追加し、AI応答の`thoughtIndex`をPreview内のHuman Thoughtだけへ解決する。
- 不正index、AI Thought index、空タグ、空理由を破棄し、内部UUIDはpromptへ送らない。
- 確定タグによる`tagGroups`とAI候補をprompt／UIで明確に分離した。類似候補では既存タグ表記を優先するよう指示するが、自動同義判定は行わない。
- Daily Summary生成ではタグを保存しない。Detailの「追加」だけが既存`ThoughtTagRepository`を呼び、追加済みはボタンを隠して表示する。
- SQLite schemaはv9のまま。WindowsにSwift／Xcodeがないためunit testとApple platform検証は未実行。
