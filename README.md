# The Etheridge Circle, 1891

A [Jido](https://hexdocs.pm/jido) multi-agent demo in Elixir. Four agents, each a character in a late-Victorian epistolary drama about a séance, grief, Theosophy and possible fraud, write letters to one another. Each character is a separate agent process holding its own private state: motives, a guilty secret, beliefs, relationship scores, and memory. Only the public text of a letter ever passes between them. The letters are generated through [OpenRouter](https://openrouter.ai) and written, with a debug section of private state changes and a final summary, to a text file.

## Setup

You need Erlang/OTP and Elixir (Homebrew: `brew install elixir`). Then:

```sh
cp .env.example .env      # add your OpenRouter key
mix deps.get
mix test                  # runs against a deterministic stub model, no network
```

`.env` is git-ignored and is read by `config/runtime.exs` at boot. `OPENROUTER_MODEL` can be any model id OpenRouter lists.

## Run

```sh
mix letters                      # ten letters; after the first, the characters decide
mix letters --letters 14
mix letters --opening            # force the scripted eight-letter opening first
mix letters --stub               # canned model output, instant, for trying the plumbing
mix letters --out story.txt
```

Letters print as they are written. At the end the debug and summary sections print, and the whole report is saved under `letters/`. A ten-letter run takes about six minutes.

## What the output shows

1. **Prologue**: the séance and the phrase "The blue ribbon was not burnt in Heaven."
2. **The letters**, in order, each with place, date, salutation, body, valediction and signature.
3. **Debug: private state changes**, clearly separated from the story. For each letter: the sender's concealed intent, visible claims and references, then the recipient's private reaction and the deltas to trust, suspicion, affection, resentment, beliefs, fear of exposure, urgency and willingness to reveal.
4. **Summary**: where every relationship and belief started and finished.

## Who writes, and why

Only the first letter is scripted: Helena to Pembroke, about the séance. From then on the characters decide. When an agent receives a letter it remembers it, appraises it privately, and chooses one of:

- **ignore it**, leaving the letter unanswered;
- **reply** to the sender;
- **write to somebody else about it**, to complain, confide, warn, confess, or tip off a collaborator;
- **write to anybody about something else** that presses on them more.

The director follows those decisions. Because the post does not wait for one conversation to finish, the director also invites any character who has neither written nor received a letter for four letters to write unprompted, choosing recipient and subject for themselves. That is also how the story continues after a silence. Every letter's origin is recorded in the debug section: "the séance", "Dr. Pembroke's decision on reading letter-003", or "unprompted; Miss Vane had not yet written or received a letter".

Every prompt includes the character's full memory of letters sent and received, and instructs them to write with that memory and never contradict what they have already written.

## Time and place

The four characters live through the same weeks of October and November 1891, but in different towns, so different things are happening around each of them. `JidoDemo1.Almanac` is a hand-curated list of what was really going on: standing descriptions of Cheltenham, London and Bath as a resident of 1891 would know them, dated local items for each town (the new theatre opening with Mrs. Langtry in Cheltenham, the Roman Great Bath lying open in Bath, the first fogs in London), and dated national news (Parnell's death, Blavatsky's followers in mourning, Tess in the Graphic, the influenza expected back). Each item is released into a character's prompt only once the story's calendar reaches its date, and only for that character's own town, with an instruction to let one or two touch the letter in passing rather than as a catalogue.

The instigating incident is an invitation from a fifth character who has no agent of her own: Mrs. Lavinia Ashworth of Cheltenham, a collector of mediums, engages Miss Vane for her Tuesday sitting and presses Helena to come. Every character knows of Mrs. Ashworth and may mention, blame, or quote her, but nobody can write to her.

Finished stories worth keeping are copied into `stories/`, which is committed; `letters/` holds every run and is ignored.

## How it is built

| Module | Role |
| --- | --- |
| `JidoDemo1.Jido` | The Jido instance: registry plus supervisor for the agents. |
| `JidoDemo1.Character` | The agent. Its schema is the whole private state of one character. Routes `letter.compose` and `letter.received` signals to actions. |
| `JidoDemo1.Cast` | The four characters as initial state, the fifth character, and the prologue. |
| `JidoDemo1.Almanac` | What was happening in each town and in the country, dated, released as the calendar advances. |
| `JidoDemo1.Letter` | Letters as structured data. `public/1` strips the sender-only fields before delivery. |
| `JidoDemo1.Actions.ComposeLetter` | Asks the model for a letter in character, remembers it, emits the public form to the recipient agent and the full form to the director. |
| `JidoDemo1.Actions.ReceiveLetter` | Stores the letter, asks the model for a private appraisal and a decision (ignore, reply, write to a third party, write about something else), applies the deltas to relationship, belief and pressure state. |
| `JidoDemo1.Actions.ChooseCorrespondent` | Deterministic fallback for whom to write to when the model names nobody valid. |
| `JidoDemo1.Prompts` | Builds prompts from a character's own state only. |
| `JidoDemo1.Appraisal` | Parses and applies the recipient's reaction. |
| `JidoDemo1.Story` | The director: starts the agents, seeds the first letter, queues and follows the characters' decisions, invites idle characters to write, and reads final state only once the story is over. |
| `JidoDemo1.Report` | Renders letters, debug and summary. |
| `JidoDemo1.LLM` | Model boundary with an OpenRouter client and a deterministic stub. |

Privacy is structural rather than a matter of prompting. A character's prompt is built from its own agent state. The recipient receives a `Letter` with `concealed_intent` and `private_note` set to nil. The director never reads agent state during the run. Tests in `test/privacy_test.exs` and `test/story_test.exs` check all three.

## Changing the drama

Edit `lib/jido_demo1/cast.ex` for the characters, their secrets, and their starting feelings toward one another. The seed letter and the optional scripted opening are the `@seed` and `@opening` attributes in `lib/jido_demo1/story.ex`.
