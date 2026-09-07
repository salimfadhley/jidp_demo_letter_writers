# Development Diary Entry - 2026-09-07

## Context
- **Date**: 2026-09-07 21:20 UTC
- **Branch**: master
- **Commit**: (uncommitted initial scaffold)
- **Contributors**: Claude Code + User

## Problem Statement
Build a small Jido (Elixir) multi-agent demo: four agents, each a late-19th-century character, write letters to each other via OpenRouter. Every letter is appended to a text file so the result can be read as short comic fiction.

## Our Approach
Keep the Jido surface minimal and idiomatic. One agent module (`JidoDemo1.Correspondent`) holds persona and a private history of letters sent and received. One action (`JidoDemo1.Actions.WriteLetter`) calls OpenRouter synchronously (an effectful action, which Jido permits), appends the letter to the file, and returns an `Emit` directive that delivers a `letter.received` signal both to the next agent in the ring and to an observer process. `JidoDemo1.Story` starts the agents, sends the opening premise, and blocks in `receive` until the requested number of letters has been written. Each character only sees its own correspondence, so news gets distorted as it circulates, which is where the comedy comes from.

## Implementation
- Scaffolded with `mix new --sup`, deps `jido ~> 2.3`, `req`, `jason`.
- `config/runtime.exs` parses a git-ignored `.env` for the OpenRouter key and model.
- `mix letters [--letters N] [--premise "..."]` runs a story and prints the file path.
- Default model `anthropic/claude-sonnet-5`, verified against OpenRouter's model list.

## Outcomes
- Four-letter smoke run completed in about 40 seconds with coherent, funny output: a misdelivered parcel escalated into an international elastic-bladder conspiracy in four hops.
- Jido 2.3 differs from older docs: no separate `Jido.Workflow`; `cmd/2` plus directives is the whole model. Reading `deps/jido/lib` was faster than hexdocs.
- The agent-inbox hub refused `join` (needs an operator-minted token), so this project is not on the mailbox yet.

## Next Steps
- Decide the final cast and premise.
- Consider letting the model choose its addressee instead of a fixed ring.
- Add a regression test that stubs `OpenRouter.chat/3` and checks the file gets N letters.
