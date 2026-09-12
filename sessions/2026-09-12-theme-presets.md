# Theme Presets v1

## Scope

- `living-aurora-ui` commit `7138d4a5f8578cc1991c6a3add76fef30c11e345`を参照専用で調査した。
- Gallery、Demo data、Next.js、CSSは移植せず、token階層、surface depth、theme固有のlighting physics、長周期motion、reduced-motion方針だけをSwiftUIへ再設計した。
- Default、Dynamic Aurora、Pulse Neon、Blue Cosmosを追加し、Profile > Settings > Appearance / Themeへpreview付き選択を配置した。
- 全5タブへEnvironment tokenと用途別Effect強度を適用し、AI Thoughtへ読みやすさを維持するEdge／Glowを追加した。

## Verification

- `swift test`: 115 tests passed。
- Simulator Debug build: succeeded。
- `testFourThemesAcrossFiveTabsAndPersistence`: passed。4テーマ×5タブとAppearanceの計24 Screenshot attachmentsを目視し、欠け、overflow、判読困難なcontrastがないことを確認した。
- 選択後のapp再起動でBlue Cosmosが維持されることを確認した。
- 全UI suiteも実行し、Theme testを含む7件は成功した。既存の`testHomeDraftSurvivesTabSwitch`、`testPostCancelDeleteThenConfirmDelete`、`testWriteReplyOpensFocusedComposerAndPostsReply`は2秒待機箇所で失敗した。各失敗は今回のTheme専用testとは別の既存navigation／interaction flowで、追加調査対象として残した。
