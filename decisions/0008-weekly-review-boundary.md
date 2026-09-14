# 0008 週間の理解と次週の意思決定を分離する

日付: 2026-09-14

## 決定

完了した月曜〜日曜のHuman Thoughtから作る`WeeklySummary`と、そのSummaryを入力に作る翌週の`WeeklyPlan`を別のdomain model／AI call／保存tableとして扱う。

週間SummaryはOpenAI `gpt-5.6-terra`、reasoning medium、最大8,192 output tokenを使う。次週Plan候補は同モデル、reasoning low、最大4,096 output tokenを使う。Plan候補はユーザーが編集して確定するまで保存しない。

## 理由

過去の記録から読み取れる事実と、未来についてユーザーが選ぶ方針は性質が異なる。分離によりAI候補を本人の決定として誤保存せず、Summary再生成時にも確定済みPlanを自動変更しない。Terraは週間の横断的理解に品質を割り当てつつ、短い出力目標とPlanのlow reasoningで費用を抑えられる。

## 帰結

- AI投稿・返信は週間Summary入力へ含めない。
- Summaryは再生成成功時だけ同じ週の保存内容を置換する。
- PlanはSummary IDを出典として保持するが、Summary置換後も自動更新しない。
- 週間機能は明示操作でのみ通信する。
