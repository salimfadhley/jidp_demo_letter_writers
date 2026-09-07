defmodule Play1.Actions.HearBeat do
  @moduledoc """
  Witness a beat spoken by somebody standing with you. Pure: it only remembers.
  A character's memory is therefore exactly the conversations it stood in.
  """

  use Jido.Action,
    name: "hear_beat",
    description: "Remember a beat witnessed in the current group",
    schema: [beat: [type: :any, required: true]]

  alias Play1.Beat

  @impl true
  def run(%{beat: raw}, %{state: state}) do
    beat = Beat.public(raw)
    {:ok, %{witnessed: Enum.take(state.witnessed ++ [beat], -40)}}
  end
end
