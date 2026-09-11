# Persona External Brain v2 / Knowledge Draft Pipeline

## 実施内容

- AI Reply／Persona Post／Daily Summaryからの明示的なKnowledge Draft生成導線を追加。
- decision／knowledge／memory／project-note、固定front matter、アプリ側safe slug、`drafts/`限定pathを実装。
- ローカルExternal Brain FTSによる関連資料最大3件の確認を追加。検索失敗時は0件として生成を継続する。
- 生成とGitHub保存を分離し、編集可能Preview後だけContents APIでnew-file-only作成するwrite境界を追加。
- tokenは既存Keychainだけから取得し、同名・権限・network失敗時はDraftを画面に保持する。
- `Knowledge Draft`をAI Usage featureへ追加し、schema v11でsource typeも保存。GitHub writeとFTS検索はAI Usageに記録しない。
- `status: draft`は既存chunkerで通常Retrievalから除外されることをテストへ追加。

## 検証

- Windows: `git diff --check`、静的差分確認。
- 未実施: Swift Package test、Xcode build、Simulator／実機、GitHub private repository実通信。`MAC_VALIDATION.md`へ記録。

## 意図的に未実装

- Draftの確定知識への昇格、既存file更新、overwrite、delete、rename、PR、merge、自動生成・自動保存、ローカルDraft履歴永続化。
