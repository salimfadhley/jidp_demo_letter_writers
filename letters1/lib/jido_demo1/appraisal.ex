defmodule JidoDemo1.Appraisal do
  @moduledoc """
  A character's private reaction to a received letter: a short note plus the
  state deltas it produces. Deltas are clamped to -2..2.
  """

  @relationship_keys [:trust, :suspicion, :affection, :resentment]
  @belief_keys [:spiritualism, :theosophy, :skepticism]

  @type t :: %{
          from: atom(),
          letter_id: String.t(),
          note: String.t(),
          relationship_deltas: %{atom() => integer()},
          belief_deltas: %{atom() => integer()},
          fear_of_exposure: integer(),
          urgency: integer(),
          willingness_to_reveal: integer(),
          new_pressure: String.t() | nil,
          decision: decision()
        }

  @typedoc "What the character resolved to do on reading the letter."
  @type decision :: %{action: :write | :ignore, to: atom() | nil, purpose: String.t() | nil}

  @doc "Build an appraisal from the model's JSON."
  @spec from_model(map(), atom(), String.t(), atom()) :: t()
  def from_model(json, from, letter_id, self_id) do
    %{
      from: from,
      letter_id: letter_id,
      note: to_string(json["appraisal"] || ""),
      relationship_deltas: deltas(json["deltas"], @relationship_keys),
      belief_deltas: deltas(json["belief_deltas"], @belief_keys),
      fear_of_exposure: clamp(json["fear_of_exposure"]),
      urgency: clamp(json["urgency"]),
      willingness_to_reveal: clamp(json["willingness_to_reveal"]),
      new_pressure: blank_to_nil(json["new_pressure"]),
      decision: decision(json["decision"], from, self_id)
    }
  end

  @doc "Parse the decision block; anything unrecognised becomes a decision to write, recipient unchosen."
  @spec decision(term(), atom(), atom()) :: decision()
  def decision(%{} = json, from, self_id) do
    action =
      if to_string(json["action"] || "") |> String.downcase() == "ignore",
        do: :ignore,
        else: :write

    to = recipient(json["to"], from, self_id)
    purpose = blank_to_nil(json["purpose"])

    case action do
      :ignore -> %{action: :ignore, to: nil, purpose: purpose}
      :write -> %{action: :write, to: to, purpose: purpose}
    end
  end

  def decision(_, _from, _self_id), do: %{action: :write, to: nil, purpose: nil}

  @doc "A short sentence describing the decision."
  @spec describe_decision(decision()) :: String.t()
  def describe_decision(%{action: :ignore, purpose: purpose}),
    do: "leaves it unanswered" <> reason(purpose)

  def describe_decision(%{action: :write, to: nil, purpose: purpose}),
    do: "resolves to write, recipient undecided" <> reason(purpose)

  def describe_decision(%{action: :write, to: to, purpose: purpose}),
    do: "resolves to write to #{JidoDemo1.Cast.short_name(to)}" <> reason(purpose)

  defp reason(nil), do: ""
  defp reason(text), do: ": #{text}"

  defp recipient(value, _from, self_id) when is_binary(value) do
    ids = JidoDemo1.Cast.ids()

    case Enum.find(ids, &(Atom.to_string(&1) == String.trim(value))) do
      nil -> nil
      ^self_id -> nil
      id -> id
    end
  end

  defp recipient(value, from, self_id) when is_atom(value) and not is_nil(value),
    do: recipient(Atom.to_string(value), from, self_id)

  defp recipient(_, _from, _self_id), do: nil

  @doc "Apply the appraisal to a character's state map, returning the changed fields."
  @spec apply(t(), map()) :: map()
  def apply(appraisal, state) do
    relationships =
      Map.update(state.relationships, appraisal.from, %{}, fn current ->
        merge_deltas(current, appraisal.relationship_deltas, -10, 10)
      end)

    pressures =
      case appraisal.new_pressure do
        nil -> state.current_pressure
        text -> Enum.take(state.current_pressure ++ [text], -5)
      end

    %{
      relationships: relationships,
      belief_state: merge_deltas(state.belief_state, appraisal.belief_deltas, 0, 10),
      current_pressure: pressures,
      fear_of_exposure: bound(state.fear_of_exposure + appraisal.fear_of_exposure, 0, 10),
      urgency: bound(state.urgency + appraisal.urgency, 0, 10),
      willingness_to_reveal:
        bound(state.willingness_to_reveal + appraisal.willingness_to_reveal, 0, 10)
    }
  end

  @doc "Human-readable one-liner of the deltas, e.g. `trust -1, suspicion +2`."
  @spec describe_deltas(%{atom() => integer()}) :: String.t()
  def describe_deltas(deltas) do
    deltas
    |> Enum.sort()
    |> Enum.reject(fn {_k, v} -> v == 0 end)
    |> case do
      [] -> "no change"
      changed -> Enum.map_join(changed, ", ", fn {k, v} -> "#{k} #{signed(v)}" end)
    end
  end

  @spec signed(integer()) :: String.t()
  def signed(v) when v > 0, do: "+#{v}"
  def signed(v), do: Integer.to_string(v)

  defp merge_deltas(current, deltas, lo, hi) do
    Enum.reduce(deltas, current, fn {key, delta}, acc ->
      Map.update(acc, key, bound(delta, lo, hi), &bound(&1 + delta, lo, hi))
    end)
  end

  defp deltas(map, keys) when is_map(map) do
    Map.new(keys, fn key -> {key, clamp(map[Atom.to_string(key)] || map[key])} end)
  end

  defp deltas(_, keys), do: Map.new(keys, &{&1, 0})

  defp clamp(value) when is_integer(value), do: bound(value, -2, 2)
  defp clamp(value) when is_float(value), do: value |> round() |> clamp()
  defp clamp(_), do: 0

  defp bound(value, lo, hi), do: value |> max(lo) |> min(hi)

  defp blank_to_nil(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      text -> text
    end
  end

  defp blank_to_nil(_), do: nil
end
