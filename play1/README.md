# An Evening at Mrs. Ashworth's

A [Jido](https://hexdocs.pm/jido) multi-agent demo in Elixir, sibling to `letters1/`. The same characters, a fortnight after the séance, are together in one drawing-room for an evening party. Instead of letters, each agent takes *beats*: a line of dialogue and a stage action, as in a play. The output is a screenplay.

## The idea

Each character carries a **game** in the sense of the Upright Citizens Brigade's theory of comic improvisation: a single point of view they cannot help seeing everything through, which they *play*, *heighten* ("do it again but more", climbing a ladder of five rungs), *explore* (explain why it is true), or *rest* (drop it and be the straight man for someone else's game). The discipline is enforced in code: no heightening twice running, one rung per heighten, never past the top.

| Character | Game |
| --- | --- |
| Mrs. Marchmont | Everything is a sign |
| Dr. Pembroke | Never the jealous man |
| Miss Vane | The convenient impression |
| Mr. Strake | The connoisseur of fraud |
| Mrs. Ashworth (hostess) | The introducer |
| The Reverend Ambrose Ashworth | Disruption: one monologue, then he is taken away |

Everyone has known everyone for years and is fond of them all, to varying degrees.

## The director

A seventh agent, the director, sets up each scene and ends it. It never writes dialogue. For each scene it decides who is in it, where in the house, and what the premise is, and heads the scene with a note that begins with who, what and where:

> Dr. Pembroke and Mrs. Marchmont meet Miss Vane in the parlour, who has a most unusual proposition.

It may plan an arrival part-way through, and once in the play it may have Mrs. Ashworth bring her brother-in-law down from the second floor to "think" for the company: a Lucky-like torrent that borders on meaninglessness and leaves everyone profoundly affected. After every beat past the fourth the director is shown the scene so far and asked whether it has reached its moment; when it says so, it writes the closing action line and records, for its own synopsis, what the scene changed. The director sees only the public script, as an audience would, never a character's private state. Its plans, verdicts and synopsis are printed after the script as "The director's book".

## Run

```sh
cp .env.example .env      # OpenRouter key
mix deps.get
mix test                  # stubbed model, instant
mix play                  # five scenes
mix play --scenes 7
mix play --stub           # canned model, to see the plumbing
```

Scripts land in `scripts/` (ignored); keepers go in `plays/` (committed).

## How it is built

| Module | Role |
| --- | --- |
| `Play1.Character` | The agent. Its schema is the whole private state: persona, secret, game and rung, relationships, and `witnessed`, the beats spoken where it stood. |
| `Play1.Cast` | The six characters, their games and ladders, the setting. |
| `Play1.Beat` | A beat as data: line, direction, addressee, game move, private inner thought, move. `public/1` strips the private fields. |
| `Play1.Actions.TakeBeat` | Asks the model for a beat, enforces the game discipline, remembers it, reports it to the stage. |
| `Play1.Actions.HearBeat` | Pure: remembers a beat witnessed in the same conversation. |
| `Play1.Director` | The director agent. Routes `scene.plan` to `PlanScene` and `scene.judge` to `JudgeScene`; keeps its plans, verdicts and synopsis. |
| `Play1.Plan` | A scene plan: who, where, premise, note, time, arrivals, disruption, beat limit. |
| `Play1.Room` | Who is in which room of the house; joining, withdrawing, leaving. |
| `Play1.Stage` | The stage manager: asks the director for each plan, sets the room, runs speaker order, delivers beats only to those in the room, asks the director when to end. Reads no private state until the end. |
| `Play1.Report` | Screenplay layout, then a separated debug section and a summary. |
| `Play1.LLM` | Model boundary with an OpenRouter client and a deterministic stub. |

Characters are aware of who is in the scene with them and who is elsewhere in the room out of earshot; they hear only what is said where they stand.
