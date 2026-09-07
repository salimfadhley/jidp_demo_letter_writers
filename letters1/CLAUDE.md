# letters1: The Etheridge Circle, 1891

Elixir/Jido multi-agent demo, one of several in this repository; run all Mix commands from this directory. Four agents, each a character in an 1891 epistolary drama, write letters via OpenRouter. See `README.md` for the run instructions and module map.

## Working here

- Elixir 1.20 / OTP 29 via Homebrew. `mix compile`, `mix format`, `mix test` (stubbed model, fast), `mix letters` (real model, about six minutes for ten letters).
- The OpenRouter key lives in `.env` (git-ignored), loaded by `config/runtime.exs`. Never commit it.
- Jido 2.3: agents are `use Jido.Agent` structs with `signal_routes`; actions are `use Jido.Action` with `run/2` returning `{:ok, state_changes, directives}`; inter-agent delivery is `%Jido.Agent.Directive.Emit{}` with a `{:pid, target: pid}` dispatch. `deps/jido` is the source of truth; hexdocs may lag.
- Jido's default action timeout is 30 s; `config/config.exs` raises it to 240 s because a model call plus one retry can exceed that.
- Privacy invariants to preserve: prompts are built only from the character's own state (`Prompts`), recipients get `Letter.public/1`, and the director never reads agent state mid-run. Tests cover these.
- The model must return JSON. `LLM.decode_json/1` repairs raw newlines inside strings and `complete_json/3` retries once; keep both when changing the client.
- Who writes next is the characters' decision, returned inside the appraisal JSON (ignore / reply / write to a third party / write about something else). The director (`Story`) queues and follows decisions and invites idle characters; it must not choose recipients itself except via the optional `--opening` script. Keep it that way.
- Cast and secrets: `lib/jido_demo1/cast.ex`. Seed letter and scripted opening: `@seed` and `@opening` in `lib/jido_demo1/story.ex`.
- Keep a dated entry in `diary/` for significant sessions.
