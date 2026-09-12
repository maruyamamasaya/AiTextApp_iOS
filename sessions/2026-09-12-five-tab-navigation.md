# 5タブ主要ナビゲーション

- 標準`TabView`でHome／Mentions／Search／Insights／Profileを構成した。
- 各タブに独立した`NavigationStack`を置き、HomeのTimeline Composer draftは既存`ThoughtStore`所有のまま維持した。
- Mention relationとReply relationを使うMentions一覧を追加した。
- 既存Thought検索をSearchタブへ、Daily Summary CalendarとThought AnalyticsをInsightsへ移した。
- Human／AI共通`ActorProfileView`をProfileタブでも再利用し、自分の場合だけ編集とSettingsをToolbarに表示した。
- Home上部のSearch／Daily Summary／Analytics／Settings導線を削除した。
- `swift test` 115件成功。Simulator Debug build成功。
- XCUITestは5タブ／Mention／Insights／Profile／Settings、検索、Analyticsが成功した。既存投稿削除テストは削除確認UIを検出できず失敗。Draft保持テストの追加実行は、並行して追加された`AppTheme.swift`のoptional `Material`コンパイルエラーで開始前に停止した。
