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

Everyone has known everyone for years and is fond of them all, to varying degrees. The curtain rises on two people talking by the fire. Others cross the room and join. In the middle Mrs. Ashworth brings her brother-in-law down from the second floor to "think" for the company: a Lucky-like torrent that borders on meaninglessness and leaves everyone profoundly affected. Late in the evening people slip away.

## Run

```sh
cp .env.example .env      # OpenRouter key
mix deps.get
mix test                  # stubbed model, instant
mix play                  # forty beats, about ten minutes
mix play --beats 56
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
| `Play1.Room` | Who stands where; joining, withdrawing, leaving. |
| `Play1.Stage` | The director: camera, speaker order, joins, the interlude, delivery of beats only to those present. Reads no private state until the end. |
| `Play1.Report` | Screenplay layout, then a separated debug section and a summary. |
| `Play1.LLM` | Model boundary with an OpenRouter client and a deterministic stub. |

Characters are aware of who is in the scene with them and who is elsewhere in the room out of earshot; they hear only what is said where they stand.
