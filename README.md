# jido_demo1

A small [Jido](https://hexdocs.pm/jido) multi-agent drama. Four Elixir agents play the correspondents in *The Etheridge Circle, 1891*, exchanging letters after a private seance exposes a phrase that each character understands differently. Each agent has its own motives, secret, relationships, beliefs, and memories; only the public portion of a letter reaches its recipient.

## Setup

You need Erlang/OTP and Elixir (Homebrew: `brew install elixir`). Then:

```sh
cp .env.example .env      # add your OpenRouter key
mix deps.get
```

`.env` is git-ignored. It is read by `config/runtime.exs` at boot. `OPENROUTER_MODEL` can be any model id that OpenRouter lists.

## Run

```sh
mix letters                       # ten letters: scripted opening, then free choice
mix letters --letters 12
mix letters --no-opening          # let characters choose recipients from the start
mix letters --stub                # deterministic run without an API call
mix letters --out story.txt
```

Each run prints letters as they arrive and writes a report under `letters/`. The report contains the public correspondence, a private state-change trace, and a summary of how relationships and beliefs shifted.

## How it works

- `JidoDemo1.Cast` defines the four characters and their initial private state.
- `JidoDemo1.Character` is the Jido agent, routing compose and receive signals to separate actions.
- `JidoDemo1.Actions.ComposeLetter` asks the configured LLM for a structured letter and dispatches only its public form.
- `JidoDemo1.Actions.ReceiveLetter` privately appraises incoming mail and updates the recipient's relationships, beliefs, and pressures.
- `JidoDemo1.Actions.ChooseCorrespondent` selects a recipient from private relationship state and unanswered mail.
- `JidoDemo1.Story` directs the sequence and waits for sent/appraised signals; it does not write prose or inspect private state during the run.
- `JidoDemo1.Report` renders the finished correspondence and post-run state summary.
- `JidoDemo1.LLM` selects OpenRouter normally and a deterministic stub for tests or `--stub` runs.

The first eight letters use a scripted opening to establish the drama. Later letters use each sender's own state to choose a recipient, allowing the social pattern to evolve without sharing one agent's secrets with another.
