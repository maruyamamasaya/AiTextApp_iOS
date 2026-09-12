# Daily SummaryをHuman Thought限定へ変更

## 要求

Daily Summaryを「人間であるユーザー本人の1日」とし、AI Personaが生成した投稿・返信・フリートーク本文を入力、件数、分析から除外する。既存Summaryは保持し、将来のAI Summaryとは責務を分離する。

## 実装

- `ThoughtRepository.fetchHumanThoughts(from:to:)`を追加した。
- SQLite実装は`thoughts`、`thought_authors`、`personas`をJOINし、期間内・未削除・`kind = human`を一括取得する。
- `PrepareDailySummary`は上記queryだけを入力とし、タグ、Relation、Continuation件数もHuman Thoughtだけで構成する。
- prompt versionを3へ更新し、AI本文を要求・補完しない指示へ変更した。
- 互換用`DailySummaryContent.aiInteractions`は維持するが、新規生成では空配列へ矯正して保存する。
- Calendar、日別詳細、送信前previewでHuman限定であることを表示し、AIのみの日は未要約対象として扱わない。
- Humanのみ、Human＋AI、交互Conversation、AIのみ、AIへのMention付きHuman、HumanへのAI返信、SQLite再起動後をテストした。

## 検証

- `swift test`: 126件成功。
- `xcodebuild -project AiTextApp.xcodeproj -scheme AiTextApp -sdk iphonesimulator -configuration Debug -derivedDataPath /tmp/AiTextAppDailySummaryDerivedData CODE_SIGNING_ALLOWED=NO build`: 成功。既存warningのみ。
