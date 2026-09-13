# 外部ブレイン接続済みAI Personaバッジ

- 外部ブレインが`verified`のAI Personaだけに、脳モチーフを使わない金色の`medal.fill`バッジを追加した。
- プロフィール、AI Persona設定一覧、Timeline、メンション候補、AI投稿依頼の選択中Personaで、名前の横へ共通表示する。
- 設定済みだけ、接続未確認、同期待ち、接続失敗の状態では表示しない。
- VoiceOver向けに「外部ブレイン接続済み」のラベルとPersona別accessibility identifierを付与した。
- `git diff --check`成功。iOS Simulator向けDebug build成功。Simulator UI実行は未実施。
