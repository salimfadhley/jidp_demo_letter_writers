defmodule Play1.Report do
  @moduledoc """
  Renders the performance as a screenplay: scene headings with the director's
  note, action lines, character cues, parentheticals and dialogue in the
  conventional columns. The director's book, a debug section and a summary
  follow the script, clearly separated.
  """

  alias Play1.{Beat, Cast}

  @rule String.duplicate("=", 72)
  @action_width 72
  @speech_width 72
  @hanging 4
  @direction_indent 8

  @spec header() :: String.t()
  def header do
    """
    AN EVENING AT MRS. ASHWORTH'S

    A play in five scenes. The Etheridge Circle, a fortnight on.

    PERSONS OF THE PLAY
    #{Enum.map_join(Cast.ids(), "\n", &"    #{Cast.stage_name(&1)}, #{Cast.name(&1)}")}

    #{action(String.trim(Cast.setting()))}
    """
  end

  @doc "One entry in stage-play form."
  @spec entry_text(term()) :: String.t()
  def entry_text({:scene, plan}) do
    """
    SCENE #{ordinal(plan.number)}

    #{action("#{String.capitalize(String.replace(plan.where, "the ", "The "))}. #{String.capitalize(String.downcase(plan.time))}. Lights up on #{Enum.map_join(plan.who, ", ", &Cast.stage_name/1)}.")}

    #{action("[Director's note: #{plan.note}]")}
    """
    |> String.trim_trailing()
  end

  def entry_text({:spotlight, who}), do: direction("[Spotlight: #{Cast.stage_name(who)}]")

  def entry_text({:closing, _number, text}),
    do: direction(text) <> "\n\n" <> direction("Lights down.")

  def entry_text({:beat, %Beat{kind: :silent} = beat}),
    do: direction("#{Cast.stage_name(beat.speaker)} #{beat.direction || "says nothing"}.")

  def entry_text({:beat, %Beat{} = beat}), do: speech(Beat.to_script(beat))

  def entry_text({:note, "CURTAIN." = text}), do: "\n" <> String.duplicate(" ", 30) <> text
  def entry_text({:note, text}), do: direction(text)

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
        Scene #{plan.number}, #{plan.where}, #{plan.time}: #{Enum.map_join(plan.who, ", ", &Cast.short_name/1)}#{arrivals(plan)}#{if plan.disruption, do: "; Ambrose brought down" <> reactions(plan), else: ""}
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
          feeling: #{feeling(b.feeling)}
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
          leaves feeling: #{feeling(Map.get(after_, :mood))}
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

  # A speech: name and line as one paragraph, wrapped with a hanging indent.
  defp speech(text), do: wrap(text, @speech_width, 0, @hanging)

  # A stage direction on its own, in parentheses, set in from the margin.
  defp direction(text) do
    text = String.trim(text)

    text =
      if String.starts_with?(text, "["),
        do: text,
        else: "(" <> String.trim_trailing(text, ".") <> ".)"

    wrap(text, @speech_width - @direction_indent, @direction_indent, 0)
  end

  defp ordinal(n),
    do: Enum.at(~w(ONE TWO THREE FOUR FIVE SIX SEVEN EIGHT NINE TEN), n - 1, Integer.to_string(n))

  defp reactions(%{reactions: r}) when map_size(r) == 0, do: ""

  defp reactions(%{reactions: r}),
    do:
      " (" <> Enum.map_join(r, ", ", fn {id, mode} -> "#{Cast.short_name(id)} #{mode}" end) <> ")"

  defp feeling(nil), do: "(none recorded)"

  defp feeling(%{emotion: e, intensity: i} = f),
    do: "#{e} (#{i}/5)#{if f[:about], do: ", about " <> f[:about], else: ""}"

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

  defp wrap(text, width, indent, hanging \\ 0) do
    pad = String.duplicate(" ", indent)
    hang = String.duplicate(" ", hanging)

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
    |> Enum.with_index()
    |> Enum.map_join("\n", fn {line, i} -> pad <> if(i == 0, do: "", else: hang) <> line end)
  end

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
