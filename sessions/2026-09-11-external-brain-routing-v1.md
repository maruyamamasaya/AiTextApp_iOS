# External Brain Routing v1 / Mac Validation backlog

- Persona別AGENT.mdのRetrieval Routeを独立Persona Postにも適用した。検索queryは明示的なユーザー依頼で、AI Replyは従来どおり会話Context＋依頼を使う。
- Persona Post previewへAGENT.md、route、source、heading、excerpt、最終payloadを追加した。
- Persona PostのUsage metadataへExternal Brain使用有無と取得chunk数を渡し、prompt versionを2へ更新した。
- Personaを持たないDaily SummaryにはExternal Brainを適用しない。
- Repository直下へ`MAC_VALIDATION.md`を追加し、Windowsで未実行のSwift Package、Xcode、migration、AI、Widget、UI、accessibility、実機、Release検証を実施順に集約した。

Windows環境にSwift toolchain／Xcodeがないため`swift test`、Xcode build、Simulator／実機確認は未実行。静的検索とGit差分検査だけを実施し、残件は`MAC_VALIDATION.md`へ記録する。
