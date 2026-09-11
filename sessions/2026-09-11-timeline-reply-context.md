# Timeline reply context

Date: 2026-09-11

## Decision

Replies remain independent Thoughts in the chronological Timeline. Each reply resolves its existing `repliesTo` relation at load time and presents the target Persona and up to two lines of the target body, similar to a mention/reply timeline. The target body is not copied into the reply record.

## Changes

- Added resolved reply targets to `ThoughtStore` alongside the existing reply target IDs.
- Displayed 「返信先 @Persona」 and a compact target-body excerpt for Human and AI replies.
- Return from Thought Detail to Timeline after a human reply is successfully saved; keep the detail and draft visible on failure.
- Kept soft-deleted targets as relationship-preserving placeholders.
- Extended the reply XCUITest to verify the context appears after returning to Timeline.

## Verification

- Debug iOS Simulator build succeeded.
- `testWriteReplyOpensFocusedComposerAndPostsReply` passed on the iPhone 17 Simulator, including automatic return to Timeline and reply-context presentation.
