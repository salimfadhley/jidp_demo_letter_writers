defmodule Play1.Character do
  @moduledoc """
  One character of the play as a Jido agent. Everything here is private to
  the process; other agents only ever receive the public form of a beat, and
  only for beats spoken in the group they were standing in.

  Signals:

  - `beat.take` routes to `Play1.Actions.TakeBeat`
  - `beat.heard` routes to `Play1.Actions.HearBeat`
  """

  use Jido.Agent,
    name: "character",
    description: "A guest or hostess at Mrs. Ashworth's evening",
    schema: [
      character_id: [type: :atom, required: true],
      public_name: [type: :string, required: true],
      role: [type: :string, required: true],
      persona: [type: :string, required: true],
      private_motivation: [type: :string, required: true],
      secret: [type: :string, required: true],
      anxiety: [type: :string, required: true],
      game: [type: :map, required: true],
      belief_state: [type: :map, required: true],
      relationships: [type: :map, required: true],
      dispositions: [type: :map, default: %{}],
      witnessed: [type: {:list, :any}, default: []],
      beats_spoken: [type: :non_neg_integer, default: 0],
      last_game_move: [type: {:or, [:atom, nil]}, default: nil],
      rung: [type: :non_neg_integer, default: 0],
      mood: [type: {:or, [:map, nil]}, default: nil],
      observer: [type: {:or, [:pid, nil]}, default: nil]
    ],
    signal_routes: [
      {"beat.take", Play1.Actions.TakeBeat},
      {"beat.heard", Play1.Actions.HearBeat}
    ]
end
