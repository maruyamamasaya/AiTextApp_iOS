# 2026-09-12 外部ブレイン日本語検索修正

## 症状

日本語の自然文でAI ReplyまたはPersona Postを依頼すると、外部ブレインの同期済みKnowledgeがあっても参照資料が0件になりやすかった。

## 原因

FTS5はtrigram tokenizerを使っている一方、検索queryは記号と空白だけで分割していた。空白を通常含まない日本語文は長い1語として引用検索され、Knowledge本文に同じ一文がない限り一致しなかった。

## 修正

- 非ASCII文字を含む長い検索語を3文字単位へ展開した。
- 検索語が多い場合は、文頭だけへ偏らないよう全文から最大12件を均等に選ぶ。
- 通常の英数字検索、route優先、最大取得件数は変更していない。
- 日本語の依頼文から関連Knowledgeを取得する回帰テストを追加した。
- prompt内で「資料提供済み」と「今回の検索が0件」を明示し、AIが0件を接続・同期失敗と誤認しないようにした。
- 送信前Previewへ取得件数を表示し、0件時の意味を説明するようにした。
- FTSで一致した語が長いheading chunkの後半にある場合、先頭固定ではなく一致箇所の周辺をAIへ渡すようにした。
- 日常利用の入力コストとGemini無料枠を考慮し、excerptを1件600文字から2,000文字へ拡張した。最大5件で約10,000文字を上限とする。

## 検証

- `swift test --filter ExternalBrainTests`: 成功（22 tests）。
- `swift test`: 成功（135 tests）。
- iOS Simulator向けDebug build: 成功。取得件数表示を含むapp targetのcompileを確認した。
- Simulator／XCUITestは実施していない。
