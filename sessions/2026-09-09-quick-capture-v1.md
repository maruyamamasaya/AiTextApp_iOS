# Phase 3-E-1 Quick Capture v1

- `origin/main`をfetchし、開始時点でHEADが最新（ahead 0 / behind 0）、作業ツリーがcleanであることを確認した。
- scene直下へ`AppRoute.quickCapture`を追加し、Timelineの即時導線から集中入力sheetを表示する。将来のWidget／App Shortcut／deep linkが同じrouteを使える。
- Quick CaptureはView-localの空draft、起動時focus、本文、文字数、投稿、キャンセルだけを持つ。タグ等は後付けとし最短入力を優先した。
- `ThoughtStore.post(_:)`へ投稿処理を共通化し、Timeline ComposerとQuick Captureの双方が既存`ThoughtTimeline.post`を使う。Quick専用Repository APIは追加していない。
- Store再入guardと送信中disableで二重投稿を防ぐ。成功時はdraftを破棄してdismissしTimelineを即時更新、失敗時は画面とdraftを保持する。
- 入力中キャンセルは破棄確認を行い、継続ならdraftを保持する。interactive dismissも入力中は無効。SQLiteへのdraft保存は行わない。
- UIテストへ起動／focus／trim投稿／単一反映、空・141文字拒否、キャンセル・破棄確認、失敗時draft保持を追加した。既存Timeline Composer testを維持した。
- Widgetは未実装。次段では直接投稿ではなくQuick Captureを開くだけの方式を第一候補とし、App GroupやExtensionからのSQLite共有を避ける。
- SQLite schemaはv4のまま。WindowsにSwift／Xcodeがないためbuild、XCUITest、実機UX確認は未実行。
