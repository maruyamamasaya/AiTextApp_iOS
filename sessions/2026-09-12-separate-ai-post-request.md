# AI Personaプロフィールと投稿依頼の分離

- Settings > AIに独立した「AIに投稿を依頼」画面を追加した。
- 投稿依頼画面はAI Persona選択、依頼文、投稿ボタンを中心にし、既存の送信前Previewと投稿成功Navigationを再利用した。
- AI Personas一覧をプロフィールへのNavigationLink中心に変更し、プロフィールから投稿依頼／おまかせ投稿を削除した。
- AIプロフィールの編集はプロフィール上部の編集ボタンから既存AI Persona editorを開く。
- `git diff --check`成功。iOS Simulator向けDebug build成功。Simulator UI実行は未実施。
