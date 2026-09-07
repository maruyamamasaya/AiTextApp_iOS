# Phase 2-B Thought History UI / Continuation Flow

- Timeline Thought全体からDetailへ遷移し、既存メニューを独立tap targetとして維持。
- rootからRelation APIで辿る`ThoughtHistory`と、分岐を古い順で安定表示する縦型Historyを追加。
- 現在Thoughtの識別、履歴内移動、削除済みThought placeholderと削除メニューを追加。
- 既存`ThoughtDraft` validationとatomic `createContinuation`を使う「続きを書く」Composerを追加。
- Continuation成功後に新Thoughtを現在位置とし、Timelineも即時更新。
- Memory repositoryもRelation／Continuation境界へ対応し、UI test isolationを維持。
- Unit Test 23件、iPhone SE (iOS 17.4) build、XCUITest 2件を確認。
