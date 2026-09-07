defmodule JidoDemo1.Actions.ChooseCorrespondent do
  @moduledoc """
  Pick whom to write to next, from private state alone.

  The choice is a deterministic heuristic rather than a model call, so it is
  inspectable and testable: a character is drawn to whoever they feel most
  strongly about, and to anyone whose letter they have not yet answered,
  and away from whoever they wrote to last.
  """

  use Jido.Action,
    name: "choose_correspondent",
    description: "Choose the next recipient from relationship state and unanswered letters",
    schema: []

  alias JidoDemo1.{Cast, Letter}

  @impl true
  def run(_params, %{state: state}) do
    {:ok, %{next_recipient: choose(state)}}
  end

  @doc "The recipient the heuristic selects for this state."
  @spec choose(map()) :: Cast.id()
  def choose(state) do
    me = state.character_id

    Cast.ids()
    |> Enum.reject(&(&1 == me))
    |> Enum.with_index()
    |> Enum.max_by(fn {other, index} -> {score(state, other), -index} end)
    |> elem(0)
  end

  @doc "How strongly the character is drawn to write to `other`."
  @spec score(map(), Cast.id()) :: integer()
  def score(state, other) do
    rel = Map.get(state.relationships, other, %{})

    feeling =
      Map.get(rel, :suspicion, 0) + Map.get(rel, :resentment, 0) + Map.get(rel, :affection, 0)

    unanswered = if unanswered?(state, other), do: 3, else: 0
    repetition = if state.last_recipient == other, do: -4, else: 0
    feeling + unanswered + repetition
  end

  defp unanswered?(state, other) do
    me = state.character_id

    state.public_memory
    |> Enum.map(&Letter.to_struct/1)
    |> Enum.reverse()
    |> Enum.find(fn l -> (l.from == other and l.to == me) or (l.from == me and l.to == other) end)
    |> case do
      %Letter{from: ^other} -> true
      _ -> false
    end
  end
end
