# AI API Usage Analytics v1

## 実装

- `AIAPIUsageRecord`、Feature／Status／Error分類、記録・分析repository境界を追加した。
- schema v10の`ai_api_usage`へ1 Call 1 metadata rowを保存し、期間と主要dimension用indexを追加した。
- Persona Post、AI Reply（External Brain含む）、Daily Summaryを共通`AIAPIUsageRecorder`へ接続した。
- Previewでは記録せず、provider request開始後だけsuccess／failed／cancelledを記録する。Retryは別Callになる。
- Telemetryは独立書込で、保存失敗を型名だけdebug logへ出し、AI生成・本文保存の結果へ伝播させない。
- tokenは実測値用nullable columnを用意したが、Firebase transportがusageを返さない現状はnil。input／output文字数は常時保存する。
- 設定の「分析」からAI使用状況Dashboardを開き、期間、件数、成功率、文字／token、Latency、Feature、Persona、Provider／Model、External Brain、Error、日別推移を表示する。
- Usage tableにはprompt、response、Thought、Summary、External Brain本文を保存しない。

## 検証

- `git diff --check`を実行した。
- `swift test`はWindowsホストにSwift executableがないため未実行。Mac/XcodeでPackage testとSimulator buildが必要。
