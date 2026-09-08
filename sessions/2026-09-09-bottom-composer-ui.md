# Bottom Composer UI

## 要求

TimelineのComposerをより細くして画面下部に配置し、文字入力開始後だけ枠内右端に投稿ボタンを表示する。

## 変更

- ComposerをTimelineの先頭から`safeAreaInset`に移し、画面下部へ固定した。
- 見出しと大きな入力面を廃止し、高さ44ptのコンパクトな入力バーにした。
- 空入力時は投稿ボタンを非表示にし、有効な文字入力中だけ文字数と投稿ボタンを枠内に表示した。
- UIテストを投稿ボタンの表示条件に合わせて更新した。

## 検証

- `git diff --check`
- `xcodebuild -project AiTextApp.xcodeproj -scheme AiTextApp -sdk iphonesimulator -configuration Debug -derivedDataPath /tmp/AiTextAppDerivedData CODE_SIGNING_ALLOWED=NO build`

