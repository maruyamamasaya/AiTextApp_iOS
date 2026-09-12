# Home検索とAI機能タブ

- 独立した検索タブを廃止し、Home上部の常設検索欄へ本文検索を移動した。
- 検索中はHomeのThought行デザインを保ったまま検索結果だけを表示し、0件時は専用Empty Stateを表示する。
- 下部の旧検索タブ位置へ「AI機能」タブを追加した。
- AI投稿依頼、AIペルソナ設定、AI使用状況、外部ブレイン、ナレッジ下書き、生成設定、OpenAI API keyをAI機能へ集約した。
- Profileから開く設定は外観・データなど一般設定に整理した。
- XCUITestの検索導線、5タブ、テーマ巡回、AI機能入口の期待値を更新した。
- `swift test`は136件成功した。
- iOS Simulator向け`build-for-testing`が成功し、アプリ本体とXCUITest targetのcompileを確認した。Simulatorテストは実行しておらず、XCTestDevicesの作成・削除は0件。
