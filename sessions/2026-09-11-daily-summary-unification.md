# Daily Summaryへの振り返り導線統一

- TimelineトップバーからHistory Reviewと独立タグ一覧の入口を撤去した。
- History Review、期間AI要約プレビュー、期間要約履歴のSwiftUI画面と`ThoughtStore`の専用presentation state／actionを削除した。
- 振り返りは月カレンダーと日別詳細を持つDaily Summaryへ統一した。
- 既存SQLiteの`review_summaries`とCore互換コードは、保存済みデータを破壊せず旧DBを開けるよう維持した。
- Thought上のタグチップへ`tag.fill`を追加し、タグ名とアイコンを組み合わせて表示するようにした。
- 旧History Review専用XCUITestを削除した。
- `swift test`: 69件成功。
- iOS Simulator向けDebug build: 成功。App Intents未使用によるmetadata extraction warningのみ。
