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
          new_pressure: String.t() | nil
        }

  @doc "Build an appraisal from the model's JSON."
  @spec from_model(map(), atom(), String.t()) :: t()
  def from_model(json, from, letter_id) do
    %{
      from: from,
      letter_id: letter_id,
      note: to_string(json["appraisal"] || ""),
      relationship_deltas: deltas(json["deltas"], @relationship_keys),
      belief_deltas: deltas(json["belief_deltas"], @belief_keys),
      fear_of_exposure: clamp(json["fear_of_exposure"]),
      urgency: clamp(json["urgency"]),
      willingness_to_reveal: clamp(json["willingness_to_reveal"]),
      new_pressure: blank_to_nil(json["new_pressure"])
    }
  end

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
