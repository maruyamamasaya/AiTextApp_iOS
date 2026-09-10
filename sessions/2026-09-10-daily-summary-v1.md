# Daily Summary v1

- schema v5へ`daily_summaries`を追加し、Thought原文とは分離して1日1件を保存。
- Calendar日境界、構造化prompt／JSON decode、送信preview／鮮度確認、0件拒否を実装。
- 月間カレンダー、日別詳細、Timeline統合、User／AIアイコン、140文字compact表示を追加。
- `swift test`: 64件成功。iOS Simulator Debug build成功。
- Gemini実通信、写真選択、各端末サイズ・VoiceOverは実機確認が必要。
