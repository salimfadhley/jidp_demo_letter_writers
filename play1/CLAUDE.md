# play1: An Evening at Mrs. Ashworth's

Elixir/Jido multi-agent demo, one of several in this repository; run all Mix commands from this directory. See `README.md`.

- Same cast as `letters1/`, now in one drawing-room. Six agents: hostess, four guests, and the visitor who speaks once.
- Each character carries a UCB-style game (`game` in `Play1.Cast`): premise, ladder of heightens, rest. `TakeBeat` enforces the discipline: no heighten twice running, one rung per heighten, never past the top.
- `Play1.Director` is an agent: it plans scenes (who, what, where, arrivals, the one disruption) and judges when to end them, seeing only the public transcript. `Play1.Stage` is the stage manager: it executes plans, runs speaker order, delivers beats only to those in the room, and reads no private state mid-run.
- Privacy: prompts are built from own state only; `Beat.public/1` strips inner thought, game move and relationship delta before delivery; a character's memory is exactly the beats spoken where it stood. Tests cover these.
- The OpenRouter key is in `.env` (git-ignored). `mix test` uses the stub. `mix play` uses the real model.
