# Decision Records

将来の担当者がコードだけでは理由を復元できない、長期的・横断的な設計判断を記録します。通常の実装詳細や作業ログはDecisionにせず、`sessions/` またはコミットへ残してください。

## 命名

`NNNN-short-title.md`（例: `0001-ui-architecture.md`）とし、番号は連番にします。状態を `Proposed`、`Accepted`、`Superseded` などで明示してください。

## Template

```markdown
# NNNN: Title

- Status: Proposed
- Date: YYYY-MM-DD

## Context
何が問題で、何が既知／未知か。

## Decision
何を決めたか。

## Reason
なぜ選んだか。

## Alternatives
検討した他案と採用しなかった理由。

## Consequences
利点、欠点、制約、後続作業。
```

Decisionを置き換える場合は過去の記録を消さず、新しいDecisionから参照して旧状態を `Superseded` にします。
