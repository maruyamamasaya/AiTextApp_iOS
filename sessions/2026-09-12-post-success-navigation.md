# 投稿成功NavigationとAI Reply Preview設定

- Profile > Settings > AIへ「AI返信の確認クッション」を追加し、OFFを既定値としてUserDefaultsへ永続化した。ONの場合だけ手動AI返信の生成後Previewを表示し、@メンションによる自動返信には確認を挟まない。
- Skip PreviewではAI Replyの生成と投稿を連続実行し、失敗時は依頼画面、エラー、再試行導線を保持するようにした。
- 通常投稿、Human Reply、Continuation、AI Reply、Persona Postの成功を共通Navigation eventへ統合した。
- 成功時はRoot TabからHomeへ戻し、各タブの深いNavigationStackをリセットして、新規Thoughtへスクロール・一時ハイライトする。
- 成功通知の生成を`handlePostSuccess`へ集約した。Home Composerからの通常投稿は現在のHome stackを再生成せず、その場で新規Thoughtへスクロール・一時ハイライトする。他画面・Sheet経由の投稿はHome選択とNavigation root再生成を行う。
- ハイライト完了後に成功通知を消費し、Homeの再生成時に古い投稿へ再度スクロールしないようにした。
- `swift test`で116件成功。Debug Simulator buildとUIテストtargetを含む`build-for-testing`に成功。Simulator UI実行はこのセッションでは行っていない。
