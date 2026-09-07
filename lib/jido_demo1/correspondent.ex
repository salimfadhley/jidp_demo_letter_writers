defmodule JidoDemo1.Correspondent do
  @moduledoc """
  A Jido agent that plays one character in the correspondence.

  Its state holds the character's persona, its own private memory of letters
  sent and received, and the id of the next character in the ring. Incoming
  `letter.received` signals are routed to `JidoDemo1.Actions.WriteLetter`.
  """

  use Jido.Agent,
    name: "correspondent",
    description: "A late-Victorian letter writer",
    schema: [
      name: [type: :string, required: true],
      persona: [type: :string, required: true],
      acquaintances: [type: :string, default: ""],
      next_id: [type: :string, required: true],
      next_name: [type: :string, required: true],
      observer: [type: :pid, required: true],
      letter_path: [type: :string, required: true],
      max_letters: [type: :pos_integer, default: 8],
      history: [type: {:list, :map}, default: []],
      letters_written: [type: :non_neg_integer, default: 0]
    ],
    signal_routes: [
      {"letter.received", JidoDemo1.Actions.WriteLetter}
    ]
end
