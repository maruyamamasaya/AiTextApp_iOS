# Home投稿ボタンを右上へ移動

- Home下部に常設していた投稿Composerをsheetへ移した。
- Home右上に` square.and.pencil `の投稿入口を追加し、表示時に入力欄へfocusする。
- 投稿成功時はsheetを閉じ、既存のHome復帰・新規Thoughtハイライトを維持する。
- 空入力または140文字超過では投稿ボタンを無効化する。
- XCUITestを新しい投稿導線に合わせて更新した。
- Actor Profileから過去の発言一覧を削除し、Home右上にHuman／AI Persona単位の投稿者フィルターを追加した。
- Debug Simulator build成功。既存の未使用変数warningのみ確認した。
