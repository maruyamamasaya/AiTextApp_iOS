# 0006 PersonaとThought投稿者関連を分離する

## Status

Accepted — 2026-09-10

## Context

現在は端末所有者1人だけがThoughtを投稿するが、将来は複数のAI Personaも同じTimelineへ投稿する。既存のThought、Relation、Tag、要約、backupを壊さず投稿者を導入する必要がある。

## Decision

- 人間とAIに共通する`Persona`を独立モデルにする。
- `thoughts`を再構築せず、1対1の`thought_authors`で投稿者を関連づける。
- schema v6 migrationで固定IDのデフォルト人間Personaを作り、全既存Thoughtを割り当てる。
- 新規ThoughtとContinuationは本文と投稿者関連を同一transactionで作成する。
- 現在のプロフィールを過去Thoughtにも表示し、Personaは将来soft deleteできる構造にする。
- 単一アイコンは最大512pxのJPEGとしてSQLite BLOBへ保存し、既存backup／Restoreへ含める。

## Consequences

通常投稿はデフォルト人間に属する。AI Personaは複数作成・編集・無効化でき、`AuthoredThoughtRepository`から明示したPersona IDで投稿できる。AI通信と生成メタデータは次段階で追加し、本文・AI設定・生成来歴はPersonaから分離したまま維持する。
