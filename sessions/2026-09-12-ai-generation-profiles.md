# 2026-09-12 AI用途別Generation Profile

## 目的

140文字のAI Persona処理へ過剰な思考量を使わず、Daily SummaryとKnowledge Draftには構造化・整理に必要な思考量を確保する。

## 実装

- `AIGenerationProfile`を生成requestへ追加し、思考量と最大出力tokenを用途ごとに一元管理した。
- Persona投稿・手動返信・自動返信はPersona設定でGemini／OpenAIを選択し、`concisePersona`（low、1,024 token）を共通利用する。
- Daily SummaryはOpenAIへ固定し、`dailySummary`（medium、8,192 token）を利用する。
- Knowledge DraftはSettingsの専用Provider選択を維持し、`knowledgeDraft`（medium、4,096 token）を利用する。旧共通Provider設定は初回読込時の互換値として引き継ぐ。
- OpenAI Responses APIへ`reasoning.effort`と`max_output_tokens`を明示し、Geminiへ`ThinkingConfig`と`maxOutputTokens`を明示する。
- SettingsとPersona編集に、各機能へ適用されるProvider・Model・思考量を表示した。

## 検証

- `swift test`: 成功（131 tests）。Persona、Daily Summary、Knowledge Draftのgeneration profile固定を含む。
- iOS Simulator向けDebug build: 成功。Firebase AI Logicの`ThinkingConfig`を含むapp targetのcompileを確認した。
- XCUITestと実API通信は実施していない。
