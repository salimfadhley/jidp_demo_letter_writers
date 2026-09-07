defmodule Play1.LLM.Stub do
  @moduledoc """
  Deterministic stand-in for the model, used in tests and `mix play --stub`.
  It answers from the options the action passes: who is speaking, the beat
  number and phase, and who is standing with them.
  """

  @behaviour Play1.LLM

  alias Play1.Cast

  @impl true
  def complete(_system, _user, opts) do
    from = Keyword.fetch!(opts, :from)
    seq = Keyword.fetch!(opts, :seq)
    phase = Keyword.fetch!(opts, :phase)
    group = Keyword.fetch!(opts, :group)
    {:ok, Jason.encode!(answer(from, seq, phase, group))}
  end

  defp answer(:ambrose_ashworth, _seq, _phase, _group) do
    %{
      "kind" => "monologue",
      "line" =>
        "Given the existence as uttered forth in the public works of the Bengal Presidency of a " <>
          "personal God quaquaqua with white beard outside time without extension who from the " <>
          "heights of divine apathia divine athambia loves us dearly with some exceptions for " <>
          "reasons unknown and suffers with those who for reasons unknown are plunged in " <>
          "torment the cricket the cricket the cricket in Bengal in Bengal the stumps the " <>
          "stumps the stumps I resume the stumps.",
      "direction" => "stands where he is put and looks at the fire",
      "addressed_to" => nil,
      "game_move" => "play",
      "inner" => nil,
      "move" => nil,
      "relationship" => nil
    }
  end

  defp answer(from, seq, phase, group) do
    others = Enum.reject(group, &(&1 == from))
    addressed = List.first(others)
    moves = ["play", "heighten", "rest", "explore"]

    %{
      "kind" => if(rem(seq, 7) == 0, do: "silent", else: "speak"),
      "line" => "#{Cast.short_name(from)} says a thing at beat #{seq}.",
      "direction" => "sips the cup",
      "addressed_to" => addressed && Atom.to_string(addressed),
      "game_move" => Enum.at(moves, rem(seq, 4)),
      "inner" => "#{Cast.short_name(from)} keeps a private thought at beat #{seq}.",
      "move" => if(:ambrose_ashworth in group, do: nil, else: move(from, seq, phase)),
      "relationship" =>
        addressed &&
          %{
            "toward" => Atom.to_string(addressed),
            "trust" => -1,
            "suspicion" => 1,
            "affection" => 0,
            "resentment" => 0
          }
    }
  end

  defp move(_from, seq, :party) when rem(seq, 9) == 0, do: %{"to" => "withdraw"}
  defp move(from, _seq, :late) when from != :lavinia_ashworth, do: %{"to" => "leave"}
  defp move(_from, _seq, _phase), do: nil
end
