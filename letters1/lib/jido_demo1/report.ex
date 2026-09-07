defmodule JidoDemo1.Report do
  @moduledoc """
  Renders a finished story: the prologue and letters (the public narrative),
  then a clearly separated debug section of private state changes, then a
  summary of how each character's relationships and beliefs shifted.
  """

  alias JidoDemo1.{Appraisal, Cast, Letter}

  @rule String.duplicate("=", 72)
  @thin String.duplicate("-", 72)

  @spec header() :: String.t()
  def header do
    """
    #{@rule}
    THE ETHERIDGE CIRCLE, 1891
    #{@rule}

    #{Cast.prologue()}
    """
  end

  @spec letter_text(Letter.t()) :: String.t()
  def letter_text(%Letter{} = letter) do
    """
    #{@thin}
    Letter #{letter.id |> String.replace("letter-", "") |> String.trim_leading("0")}: #{Cast.name(letter.from)} to #{Cast.name(letter.to)}
    #{@thin}

    #{Letter.to_text(letter)}
    """
  end

  @doc "The complete report."
  @spec render([map()], %{Cast.id() => map()}, %{Cast.id() => map()}) :: String.t()
  def render(entries, initial, final) do
    [
      header(),
      Enum.map_join(entries, "\n", &letter_text(&1.letter)),
      debug_section(entries),
      summary_section(initial, final)
    ]
    |> Enum.join("\n")
  end

  @doc "Private state changes, letter by letter. Not part of the narrative."
  @spec debug_section([map()]) :: String.t()
  def debug_section(entries) do
    body =
      Enum.map_join(entries, "\n", fn %{letter: letter, appraisal: appraisal} = entry ->
        recipient = Cast.short_name(letter.to)
        origin = Map.get(entry, :origin, "")

        appraisal_lines =
          case appraisal do
            nil ->
              "  #{recipient}: (no appraisal recorded)"

            a ->
              """
                #{recipient} privately: #{a.note}
                #{recipient} toward #{Cast.short_name(letter.from)}: #{Appraisal.describe_deltas(a.relationship_deltas)}
                #{recipient} beliefs: #{Appraisal.describe_deltas(a.belief_deltas)}
                #{recipient} fear of exposure #{Appraisal.signed(a.fear_of_exposure)}, urgency #{Appraisal.signed(a.urgency)}, willingness to reveal #{Appraisal.signed(a.willingness_to_reveal)}
                #{recipient} #{Appraisal.describe_decision(Map.get(a, :decision, %{action: :write, to: nil, purpose: nil}))}
              """
              |> String.trim_trailing()
          end

        """
        #{letter.id} #{Cast.short_name(letter.from)} -> #{recipient} [tone: #{letter.emotional_tone}]
          why this letter: #{origin}
          concealed intent: #{letter.concealed_intent || "(none stated)"}
          visible claims: #{list(letter.visible_claims)}
          references: #{list(letter.references)}
        #{appraisal_lines}
        """
      end)

    """
    #{@rule}
    DEBUG: PRIVATE STATE CHANGES (not part of the story)
    #{@rule}

    #{body}
    """
  end

  @doc "Where every relationship and belief started and finished."
  @spec summary_section(%{Cast.id() => map()}, %{Cast.id() => map()}) :: String.t()
  def summary_section(initial, final) do
    body =
      Enum.map_join(Cast.ids(), "\n", fn id ->
        before = initial[id]
        after_ = final[id]

        relationships =
          Enum.map_join(Cast.ids() -- [id], "\n", fn other ->
            "  toward #{Cast.short_name(other)}: " <>
              movement(before.relationships[other], after_.relationships[other])
          end)

        """
        #{Cast.name(id)}
        #{relationships}
          beliefs: #{movement(before.belief_state, after_.belief_state)}
          fear of exposure #{before.fear_of_exposure} -> #{after_.fear_of_exposure}, urgency #{before.urgency} -> #{after_.urgency}, willingness to reveal #{before.willingness_to_reveal} -> #{after_.willingness_to_reveal}
          pressures now: #{list(after_.current_pressure)}
        """
      end)

    """
    #{@rule}
    SUMMARY: HOW THE CIRCLE SHIFTED
    #{@rule}

    #{body}
    """
  end

  defp movement(before, after_) do
    before
    |> Enum.sort()
    |> Enum.map_join(", ", fn {key, was} ->
      now = Map.get(after_, key, was)
      delta = now - was

      if delta == 0,
        do: "#{key} #{was}",
        else: "#{key} #{was} -> #{now} (#{Appraisal.signed(delta)})"
    end)
  end

  defp list([]), do: "(none)"
  defp list(items), do: Enum.join(items, "; ")
end
