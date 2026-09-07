# jido_demo1

Elixir/Jido multi-agent demo: four LLM-backed characters write comic letters to each other in a ring, appended to a text file under `letters/`. See `README.md` for the run instructions and module map.

## Working here

- Elixir 1.20 / OTP 29 via Homebrew. Build with `mix compile`, format with `mix format`, run with `mix letters`.
- The OpenRouter key lives in `.env` (git-ignored), loaded by `config/runtime.exs`. Never commit it.
- Jido 2.3: agents are `use Jido.Agent` structs with `signal_routes`; actions are `use Jido.Action` with `run/2` returning `{:ok, state_changes, directives}`; inter-agent delivery is an `%Jido.Agent.Directive.Emit{}` with a `{:pid, target: pid}` dispatch. The API in `deps/jido` is the source of truth; hexdocs may lag.
- Cast lives in `lib/jido_demo1/characters.ex`. Prompts live in `lib/jido_demo1/actions/write_letter.ex`.
- Keep a dated entry in `diary/` for significant sessions.
