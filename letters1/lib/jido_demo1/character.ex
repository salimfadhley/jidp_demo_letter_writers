defmodule JidoDemo1.Character do
  @moduledoc """
  One character of the drama as a Jido agent.

  Everything in this state is private to the agent process. Other agents only
  ever receive the public form of a letter (see `JidoDemo1.Letter.public/1`),
  and the director only sees what the agent chooses to emit to it.

  Signals:

  - `letter.compose` routes to `JidoDemo1.Actions.ComposeLetter`
  - `letter.received` routes to `JidoDemo1.Actions.ReceiveLetter`
  """

  use Jido.Agent,
    name: "character",
    description: "A correspondent in The Etheridge Circle, 1891",
    schema: [
      character_id: [type: :atom, required: true],
      public_name: [type: :string, required: true],
      location: [type: :string, required: true],
      social_class: [type: :string, required: true],
      public_persona: [type: :string, required: true],
      private_motivation: [type: :string, required: true],
      guilty_secret: [type: :string, required: true],
      anxiety: [type: :string, required: true],
      temperament: [type: {:list, :string}, default: []],
      spiritual_position: [type: :string, required: true],
      knowledge_of_event: [type: :string, required: true],
      belief_state: [type: :map, required: true],
      relationships: [type: :map, required: true],
      dispositions: [type: :map, default: %{}],
      private_memory: [type: {:list, :string}, default: []],
      public_memory: [type: {:list, :any}, default: []],
      current_pressure: [type: {:list, :string}, default: []],
      fear_of_exposure: [type: :integer, default: 0],
      urgency: [type: :integer, default: 0],
      willingness_to_reveal: [type: :integer, default: 0],
      observer: [type: {:or, [:pid, nil]}, default: nil],
      next_recipient: [type: {:or, [:atom, nil]}, default: nil],
      last_recipient: [type: {:or, [:atom, nil]}, default: nil],
      last_letter: [type: :any, default: nil],
      last_appraisal: [type: :any, default: nil],
      letters_sent: [type: :non_neg_integer, default: 0]
    ],
    signal_routes: [
      {"letter.compose", JidoDemo1.Actions.ComposeLetter},
      {"letter.received", JidoDemo1.Actions.ReceiveLetter}
    ]
end
