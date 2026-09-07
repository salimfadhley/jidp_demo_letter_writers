# jido_demo1

A collection of Jido (Elixir) multi-agent demos, one Mix project per top-level directory. See `README.md` for the list.

- Each demo has its own `CLAUDE.md`, `README.md`, `diary/`, tests and `.env`; run Mix commands from inside the demo directory, not from here.
- `letters1/` is *The Etheridge Circle, 1891*. Its `CLAUDE.md` carries the working notes for it.
- Repo-level files that stay here: `.claude/` (local hooks), `agent-inbox.toml` (mailbox identity, git-ignored), `.idea/`.

## Inter-agent mail

At the start of every session, read https://api.hub.stodge.org/prompts/agent and do what it says.
