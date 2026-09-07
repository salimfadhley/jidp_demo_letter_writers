defmodule Play1.Report do
  @moduledoc """
  Renders the performance as a screenplay: scene headings with the director's
  note, action lines, character cues, parentheticals and dialogue in the
  conventional columns. The director's book, a debug section and a summary
  follow the script, clearly separated.
  """

  alias Play1.{Beat, Cast}

  @rule String.duplicate("=", 72)
  @action_width 62
  @name_indent 22
  @paren_indent 16
  @dialogue_indent 10
  @dialogue_width 38

  @spec header() :: String.t()
  def header do
    """
    AN EVENING AT MRS. ASHWORTH'S

    The Etheridge Circle, a fortnight on.

    #{action(String.trim(Cast.setting()))}

    FADE IN:
    """
  end

  @doc "One entry in screenplay form."
  @spec entry_text(term()) :: String.t()
  def entry_text({:scene, plan}) do
    """
    SCENE #{plan.number}

    INT. #{Cast.heading(plan.where)}, MRS. ASHWORTH'S HOUSE - NIGHT, #{plan.time}

    #{action("[Director's note: #{plan.note}]")}

    #{action("#{Enum.map_join(plan.who, ", ", &Cast.stage_name/1)}, #{String.replace(plan.where, "the ", "in the ")}.")}
    """
    |> String.trim_trailing()
  end

  def entry_text({:closing, _number, text}),
    do: action(text) <> "\n\n" <> String.duplicate(" ", 50) <> "CUT TO:"

  def entry_text({:beat, %Beat{kind: :silent} = beat}),
    do: action("#{Cast.stage_name(beat.speaker)} #{beat.direction || "says nothing"}.")

  def entry_text({:beat, %Beat{} = beat}) do
    paren =
      case {beat.kind, beat.direction} do
        {:aside, nil} -> "(aside)"
        {:aside, d} -> "(aside; #{trim_dot(d)})"
        {_, nil} -> nil
        {_, d} -> "(#{trim_dot(d)})"
      end

    [
      String.duplicate(" ", @name_indent) <> Cast.stage_name(beat.speaker),
      paren && wrap(paren, @dialogue_width - 4, @paren_indent),
      wrap(beat.line || "", @dialogue_width, @dialogue_indent)
    ]
    |> Enum.reject(&is_nil/1)
    |> Enum.join("\n")
  end

  def entry_text({:note, text}), do: action(text)

  @spec render([term()], map(), map(), map()) :: String.t()
  def render(entries, initial, final, director) do
    [
      header(),
      Enum.map_join(entries, "\n\n", &entry_text/1),
      "",
      director_section(director),
      debug_section(entries),
      summary_section(initial, final)
    ]
    |> Enum.join("\n")
  end

  @doc "The director's plans and verdicts, scene by scene."
  @spec director_section(map()) :: String.t()
  def director_section(director) do
    plans =
      Enum.map_join(director.plans, "\n", fn plan ->
        """
        Scene #{plan.number}, #{plan.where}, #{plan.time}: #{Enum.map_join(plan.who, ", ", &Cast.short_name/1)}#{arrivals(plan)}#{if plan.disruption, do: "; Ambrose brought down", else: ""}
          note: #{plan.note}
          premise: #{plan.premise}
          goal: #{plan.dramatic_goal || "(none)"}
        """
      end)

    endings =
      director.verdicts
      |> Enum.filter(&(&1.decision == :end))
      |> Enum.map_join(
        "\n",
        &"  ended: #{&1.reason || "(no reason)"}\n  record: #{&1.summary || "(none)"}"
      )

    """
    #{@rule}
    THE DIRECTOR'S BOOK (not part of the play)
    #{@rule}

    #{plans}
    Endings:
    #{endings}

    Synopsis:
    #{Enum.join(director.synopsis, "\n")}
    """
  end

  @spec debug_section([term()]) :: String.t()
  def debug_section(entries) do
    body =
      entries
      |> Enum.filter(&match?({:beat, _}, &1))
      |> Enum.map_join("\n", fn {:beat, b} ->
        with_ = Enum.map_join(b.group -- [b.speaker], ", ", &Cast.short_name/1)

        """
        #{b.seq} #{Cast.short_name(b.speaker)} in #{b.place} with #{if with_ == "", do: "nobody", else: with_} [#{b.kind}; game: #{b.game_move}, rung #{b.rung}]
          inner: #{b.inner || "(none)"}
          move: #{inspect(b.move)}; relationship: #{inspect(b.relationship)}
        """
      end)

    """
    #{@rule}
    DEBUG: PRIVATE STATE PER BEAT (not part of the play)
    #{@rule}

    #{body}
    """
  end

  @spec summary_section(map(), map()) :: String.t()
  def summary_section(initial, final) do
    body =
      Enum.map_join(Cast.ids(), "\n", fn id ->
        before = initial[id]
        after_ = final[id]

        relationships =
          Enum.map_join(Cast.ids() -- [id], "\n", fn other ->
            "  toward #{Cast.short_name(other)}: #{movement(before.relationships[other] || %{}, after_.relationships[other] || %{})}"
          end)

        """
        #{Cast.name(id)}: game "#{after_.game.name}", reached rung #{after_.rung} of #{length(after_.game.ladder)}, #{after_.beats_spoken} beats
        #{relationships}
        """
      end)

    """
    #{@rule}
    SUMMARY: HOW THE EVENING MOVED THEM
    #{@rule}

    #{body}
    """
  end

  # --- formatting ---

  defp arrivals(%{arrivals: []}), do: ""

  defp arrivals(%{arrivals: list}),
    do:
      "; arriving: " <>
        Enum.map_join(list, ", ", &"#{Cast.short_name(&1.who)} after beat #{&1.after_beats}")

  defp action(text) do
    text
    |> String.split(~r/\n\s*\n/)
    |> Enum.map_join("\n\n", &wrap(String.replace(&1, ~r/\s*\n\s*/, " "), @action_width, 0))
  end

  defp wrap(text, width, indent) do
    pad = String.duplicate(" ", indent)

    text
    |> String.split(~r/\s+/, trim: true)
    |> Enum.reduce([], fn word, lines ->
      case lines do
        [] ->
          [word]

        [current | rest] when byte_size(current) + 1 + byte_size(word) <= width ->
          [current <> " " <> word | rest]

        _ ->
          [word | lines]
      end
    end)
    |> Enum.reverse()
    |> Enum.map_join("\n", &(pad <> &1))
  end

  defp trim_dot(text), do: text |> String.trim() |> String.trim_trailing(".")

  defp movement(before, _after) when map_size(before) == 0, do: "(none)"

  defp movement(before, after_) do
    before
    |> Enum.sort()
    |> Enum.map_join(", ", fn {key, was} ->
      now = Map.get(after_, key, was)
      if now == was, do: "#{key} #{was}", else: "#{key} #{was} -> #{now}"
    end)
  end
end
