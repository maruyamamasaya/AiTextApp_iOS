# 0001: Keep canonical Thoughts in local JSON behind a repository

- Status: Accepted
- Date: 2026-09-07

## Context
Phase 1-A needs durable local storage without dependencies, while later AI-derived data must not pollute the human-authored Thought model.

## Decision
Store Codable Thought records in an atomically written Application Support JSON file behind `ThoughtRepository`. Keep only identity, body, created/updated timestamps, and a deletion timestamp on Thought. Use soft deletion. Future AI output will use separate models and storage responsibilities linked by Thought ID.

## Reason
The repository boundary keeps UI and use cases independent of the initial persistence choice. JSON is sufficient for the small local dataset, transparent, dependency-free, and testable on Linux.

## Alternatives
SwiftData/Core Data would provide queries and migrations but raises the deployment/tooling surface before Phase 1-A needs it. UserDefaults is poorly suited to a growing collection.

## Consequences
Writes currently encode the complete collection and are appropriate only while the local dataset is small. Schema migration and corrupt-file recovery must be designed before incompatible model changes. AI metadata must not be added to Thought.
