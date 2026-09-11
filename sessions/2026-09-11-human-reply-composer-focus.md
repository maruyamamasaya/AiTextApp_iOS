# AI reply-chain composer interaction fix

Date: 2026-09-11

## Problem

In an AI reply chain, `ThoughtDetailView` changed the human reply composer state when 「返信を書く」 was tapped, but its `TextEditor` was not connected to the view's `FocusState`. On compact screens the composer could be inserted below the visible area without bringing the input into view, making the button appear unresponsive.

This button is the human-to-AI turn in the AI conversation flow. Posting it preserves the `repliesTo` chain and automatically mentions the AI that authored the target Thought, enabling the next 「AIに返信を依頼」 action.

## Changes

- Connected the human reply `TextEditor` to `composerIsFocused`.
- Focus the reply editor when opening it.
- Made the continuation and reply composers mutually exclusive.
- Added an XCUITest covering button tap, keyboard presentation, reply entry, persistence, and composer dismissal.

## Verification

- Debug iOS Simulator build succeeded.
- `testWriteReplyOpensFocusedComposerAndPostsReply` passed on the iPhone 17 Simulator.
- `humanReplyToAIContinuesReplyChainAndMentionsThatAI` passed, confirming the AI author is mentioned and the reply remains in the same AI reply chain.
