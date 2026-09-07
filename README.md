# jido_demo1

A small [Jido](https://hexdocs.pm/jido) multi-agent demo. Four Elixir agents, each playing a late-Victorian character, write letters to one another in a ring. Each letter is generated through [OpenRouter](https://openrouter.ai) and appended to a plain-text file, so the finished story can simply be read.

## Setup

You need Erlang/OTP and Elixir (Homebrew: `brew install elixir`). Then:

```sh
cp .env.example .env      # add your OpenRouter key
mix deps.get
```

`.env` is git-ignored. It is read by `config/runtime.exs` at boot. `OPENROUTER_MODEL` can be any model id that OpenRouter lists.

## Run

```sh
mix letters                       # eight letters, default premise
mix letters --letters 12
mix letters --premise "The vicar has announced a bicycle race."
```

Each run writes a fresh file under `letters/`, for example `letters/correspondence-20260907-211718.txt`, and prints the path when done.

## How it works

- `JidoDemo1.Jido` is the Jido instance: a registry plus supervisor for agents.
- `JidoDemo1.Correspondent` is the agent. Its state holds a persona, a private memory of letters sent and received, and the id of the next character. It routes `letter.received` signals to one action.
- `JidoDemo1.Actions.WriteLetter` does the work: it asks OpenRouter for a letter in character, appends it to the story file, and emits a `letter.received` signal to the next agent and to the observer.
- `JidoDemo1.Story` starts one agent per character, sends the opening premise to the first, and waits as the observer until the requested number of letters exist. It then stops the agents.
- `JidoDemo1.Characters` is the cast. Edit it to change who is writing.

Each character only knows the letters it has itself sent and received, so news is passed along, embellished and misreported round the ring.
