# Development Diary Entry - 2026-09-07 (second session)

## Context
- **Date**: 2026-09-07 22:50 UTC
- **Branch**: master
- **Commit**: (uncommitted; remote `origin` set to github.com/salimfadhley/jidp_demo_letter_writers)
- **Contributors**: Claude Code + User

## Problem Statement
Replace the placeholder comic-letter demo with the user's full specification: *The Etheridge Circle, 1891*, four characters with public personas, private motives, guilty secrets, relationship scores and beliefs, exchanging letters after a séance. Output should be ten letters, opening with the instigating incident, followed by a separated debug section of private state and a summary of how relationships shifted. Each character must be a single agent so its thoughts stay private.

## Our Approach
One `JidoDemo1.Character` agent per character; its schema is the entire private state. Two model-backed actions: `ComposeLetter` (writes, remembers, emits the public letter to the recipient and the full letter to the director) and `ReceiveLetter` (remembers, asks the model for a private appraisal, applies clamped deltas). A deterministic `ChooseCorrespondent` heuristic picks recipients after the scripted eight-letter opening. The director (`Story`) only schedules and listens; it reads agent state once, at the end, for the summary. A `LLM` behaviour with an OpenRouter client and a canned `Stub` makes the whole simulation runnable under test without network.

## Implementation
- `Letter` struct with `public/1` stripping `concealed_intent` and `private_note`.
- `Cast` holds the four characters verbatim from the spec, plus a prologue describing the séance.
- `Report` renders prologue, letters, debug and summary; the Mix task prints letters as they arrive.
- 22 tests: letter fields, privacy of prompts and delivered letters, memory and relationship updates on receipt, heuristic choice, and full stubbed runs including determinism across two runs.

## Outcomes
- First real run failed on letter 3: the model put a raw newline inside a JSON string. Added a control-character repair pass and one retry.
- Second run reached letter 10 then died: the letter was cut off at `max_tokens` 1500, and the retry pushed the action past Jido's 30 s default action timeout. Raised the token cap to 4000, surfaced `finish_reason: length` as an error, set `:jido_action, :default_timeout` to 240 s, and made the director save a partial report on failure.
- Third run: ten letters in six minutes, no retries. Emergent detail worth noting: Clara invented a daughter "Cecily" in letter 3; Helena's private appraisal caught the slip and it became the engine of letters 8 to 10, with Pembroke reading it as a symptom and Helena as an omen. Nobody scripted that.
- Jido Pods were considered for the "group" but are a topology feature with plugins and mutation reports; a named set of agents under one instance is the right size for this demo.

## Later the same evening: agency

The user clarified that a character receiving a letter must be free to ignore it, reply, write to a third party about it, or write about something unrelated, always with memory of what they have received. The appraisal prompt now also returns a decision, and the director follows it instead of choosing recipients. First real run: Helena and Pembroke replied to each other ten times and nobody else appeared, which is faithful but dull. Added idle invitations (a character with no post for four letters is asked to write, recipient of their own choosing) and a per-character decision queue where a newer decision replaces an older one. Second run: Clara and Strake entered unprompted at letters 5 and 6, and every other letter was a recorded decision. Nobody chose to ignore a letter or to write to a third party this time; the options are there and the stub tests cover them.

## Next Steps
- Let the model choose its recipient in free rounds, with the heuristic as fallback, to compare emergent behaviour.
- Consider a model-written epilogue or a fifth "event" injected mid-run to test how the agents absorb new information.
- Commit and push once the user is happy with the shape.
