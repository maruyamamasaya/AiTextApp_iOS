# AI Agent Guide

このリポジトリでは、ソースコード・設定・テストを実装状態の正本とします。文書と矛盾した場合は実物を再調査し、「実装上の事実」「意図された仕様」「過去の判断」「不具合」を区別して文書を直してください。

## 作業開始時

1. `CURRENT.md` を読む。
2. この `AGENTS.md` のルールを確認する。
3. 必要に応じて `ARCHITECTURE.md` を読む。
4. コードの場所は `CODEMAP.md` から探す。
5. 検証方法は `TESTING.md` を確認する。
6. 環境・起動・運用・配布の変更では `OPERATIONS.md` を確認する。
7. 設計判断が関係する場合は `decisions/` を確認する。

推奨導線は `CURRENT.md` → 必要な専門文書 → `CODEMAP.md` → コード検索 → 対象コードです。

## コード調査時

全ファイルを順に読む前に、`rg`、`git grep`、IDEのシンボル検索、language serverなど利用可能な検索を使います。関数名、型・クラス・Component名、Route/API path、DB table、環境変数、エラーメッセージ、feature名、test名、`TODO|FIXME` を手掛かりにしてください。

```bash
rg "FeatureName|TypeName"
rg "/api/example"
rg "DATABASE_URL|TODO|FIXME"
git grep "error message"
```

検索結果から **入口 → 主要処理 → データアクセス → 外部依存 → テスト** の順に、呼び出し元・呼び出し先を確認してから変更します。一般的な流れは、文書を読む → キーワード検索 → 関連コード特定 → 呼び出し関係確認 → 関連テスト特定 → 変更 → 検証です。

## 作業中

- 既存仕様を尊重し、コードだけから仕様を決めつけない。
- 不明点を推測で固定せず、必要なら「未確認」と記録する。
- 要求に関係する範囲だけを、小さく安全に変更する。
- 不要なリファクタリング、依存更新、機能追加を混ぜない。
- 実装前に関連テストを探し、変更の境界を把握する。
- 将来の担当者が理由を推測できない重要判断だけ `decisions/` に記録する。
- 認証情報、署名情報、トークン、個人情報を文書やコミットへ含めない。

## 作業終了時

変更に応じて `TESTING.md` から lint、typecheck、unit/integration/E2E test、buildを選んで実行します。その後、次を必要な場合だけ更新します。

- 毎回: `sessions/` に簡潔な作業記録を残す。
- 状態変更: `CURRENT.md`
- 構成変更: `ARCHITECTURE.md`
- 主要コード配置変更: `CODEMAP.md`
- 検証方法変更: `TESTING.md`
- 起動・環境・配布方法変更: `OPERATIONS.md`

## 文書の役割

- `CURRENT.md`: 今どこまでできているか。
- `ARCHITECTURE.md`: 現在システムがどう動いているか。
- `CODEMAP.md`: どの主要コードがどこにあるか。
- `TESTING.md`: どう検証するか。
- `OPERATIONS.md`: どう起動・運用・デプロイするか。
- `decisions/`: なぜ重要な設計を選んだか。
- `sessions/`: 過去に何を調査・変更したか。
- `README.md`: 人間向けの概要と入口。
