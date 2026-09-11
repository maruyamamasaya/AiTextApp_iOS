# AI使用状況の設定内配置

## 変更

- Thought詳細画面に置かれていた「AI使用状況」への導線を削除した。
- 設定画面の「AI」セクションへ同じNavigationLinkとaccessibility identifierを移した。
- Usage Dashboardと集計・永続化処理は変更していない。

## 検証

- `swift test`
- Xcode Simulator build
- `git diff --check`
