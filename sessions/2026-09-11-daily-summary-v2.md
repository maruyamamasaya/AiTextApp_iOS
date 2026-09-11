# Daily Summary v2

- Human Thoughtを主分析、AI Thought／ReplyをPersona別の「AIとの対話」へ分離した。
- Human Thoughtの実タグだけからtyped `tagGroups`を作り、AIタグや架空タグを生成後に除外する。
- 共通`TimeOfDay`、端末Calendar／timezone、日内`continues`／`repliesTo`を内部UUIDなしの構造化promptへ追加した。
- 時間帯は意味がある場合だけ出力し、少数データ、性格・生活習慣、診断的表現を断定しない指示を追加した。
- Previewへ本文・時刻・投稿者・Humanタグ・Relationを固定し、送信直前の完全比較でstale payloadを止める。
- v2 typed model（タグ別、AI対話、時間帯）を追加し、v1 JSONの欠落fieldは空配列へ補完する。SQLite schemaはv9のまま。
- DetailをHuman中心の順へ再構成し、タグ別／AI対話／時間帯は空の場合に非表示とした。
- WindowsにSwift／Xcodeがないためunit test、build、Simulator、XCUITest、Firebase実通信、実機・アクセシビリティ目視は未実行。
