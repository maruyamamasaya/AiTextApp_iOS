# Knowledge Quality & Consolidation v1

## 目的・実装

Knowledge増加時の重複・類似・陳腐化を、本文や状態を自動変更せずHumanへ候補提示する。Knowledge管理にQuality画面、Compare、Dismiss、Merge Draft、Archive、Supersede、Recently Usedを追加した。

## DB・Detection・Retrieval

- schema v13でKnowledge status、supersededBy、archivedAt、retrievalCount、lastRetrievedAt、Quality Candidateを永続化。
- normalized title／body一致、本文token Jaccard、tag overlapでDuplicate／Similar候補を作る。180日未更新かつ未参照をStale候補とする。
- active Knowledgeだけusage更新対象とし、Archive／Supersede時はローカルindexから除外する。履歴用SQLite documentは削除しない。

## Merge・Analytics・Safety

- MergeはA/B本文を並べ、source IDs／paths／reasonをprovenanceに持つ通常Knowledge Draftとして既存Review Pipelineへ戻す。
- Quality解析とMerge Draft作成はAI APIを使用しない。自動削除・自動Archive・自動Supersede・自動Promote・既存GitHub Markdown更新は行わない。

## Tests・未検証

- duplicate／unrelated／stale、usage更新、dismiss、本文不変、Archive／Supersede metadataのpure／repositoryテストを追加。
- Windowsでは静的差分のみ。schema migration、Swift test、Quality／Compare UI、実Retrieval、再起動永続化は`MAC_VALIDATION.md`へ記録。

## 次フェーズ候補

- 差分解析のfingerprint永続化、期間別usage、双方向supersede表示、明示操作型AI Merge案。
