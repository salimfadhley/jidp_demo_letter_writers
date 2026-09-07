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
    case Keyword.get(opts, :kind) do
      :plan -> {:ok, Jason.encode!(plan(opts))}
      :judge -> {:ok, Jason.encode!(judge(opts))}
      _ -> beat(opts)
    end
  end

  # Fixed scene plans, so tests see two-handers, an arrival, the disruption, and an ending.
  defp plan(opts) do
    number = Keyword.fetch!(opts, :number)
    total = Keyword.fetch!(opts, :total)

    base =
      case rem(number, 4) do
        1 ->
          %{
            "who" => ["helena_marchmont", "arthur_pembroke"],
            "where" => "the drawing-room",
            "arrivals" => [%{"who" => "clara_vane", "after_beats" => 3}],
            "disruption" => false
          }

        2 ->
          %{
            "who" => ["clara_vane", "julian_strake"],
            "where" => "the conservatory",
            "arrivals" => [],
            "disruption" => false
          }

        3 ->
          %{
            "who" => ["lavinia_ashworth", "helena_marchmont", "arthur_pembroke", "julian_strake"],
            "where" => "the drawing-room",
            "arrivals" => [],
            "disruption" => true
          }

        0 ->
          %{
            "who" => ["lavinia_ashworth", "clara_vane"],
            "where" => "the parlour",
            "arrivals" => [%{"who" => "julian_strake", "after_beats" => 2}],
            "disruption" => false
          }
      end

    Map.merge(base, %{
      "time" => if(number == 1, do: "CONTINUOUS", else: "LATER"),
      "note" =>
        "Stub note for scene #{number}: #{Enum.join(base["who"], " and ")} in #{base["where"]}.",
      "premise" => "Stub premise for scene #{number}.",
      "dramatic_goal" => "Stub goal.",
      "opening_line_by" => hd(base["who"]),
      "spotlight" => hd(base["who"]),
      "max_beats" => if(number == total, do: 6, else: 8)
    })
  end

  # End every scene after six beats, or when forced; move the spotlight every three beats.
  defp judge(opts) do
    beats = Keyword.fetch!(opts, :beats)
    ending = Keyword.fetch!(opts, :forced) or beats >= 6
    present = Keyword.get(opts, :present, [])

    spotlight =
      if present == [], do: nil, else: Enum.at(present, rem(div(beats, 3), length(present)))

    %{
      "decision" => if(ending, do: "end", else: "continue"),
      "spotlight" => spotlight && Atom.to_string(spotlight),
      "thing_shown" => beats >= 3,
      "reason" => "Stub reason.",
      "closing" =>
        if(ending,
          do: "Stub closing line for scene #{Keyword.fetch!(opts, :number)}: nobody answers.",
          else: nil
        ),
      "summary" =>
        if(ending, do: "Stub summary of scene #{Keyword.fetch!(opts, :number)}.", else: nil)
    }
  end

  defp beat(opts) do
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

  defp move(_from, seq, :scene) when rem(seq, 11) == 0, do: %{"to" => "withdraw"}
  defp move(from, _seq, :last) when from != :lavinia_ashworth, do: %{"to" => "leave"}
  defp move(_from, _seq, _phase), do: nil
end
