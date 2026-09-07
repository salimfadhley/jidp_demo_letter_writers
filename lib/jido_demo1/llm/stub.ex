defmodule JidoDemo1.LLM.Stub do
  @moduledoc """
  Deterministic stand-in for the model, used in tests and `mix letters --stub`.

  It ignores the prompt text and answers from the `:kind`, `:from` and `:to`
  options that the actions pass alongside every request.
  """

  @behaviour JidoDemo1.LLM

  alias JidoDemo1.Cast

  @impl true
  def complete(_system, _user, opts) do
    kind = Keyword.fetch!(opts, :kind)
    from = Keyword.fetch!(opts, :from)
    to = Keyword.fetch!(opts, :to)
    {:ok, Jason.encode!(answer(kind, from, to))}
  end

  defp answer(:compose, from, to) do
    %{
      "salutation" => "My dear #{Cast.short_name(to)},",
      "body" =>
        "I write from #{Cast.location(from)} under conditions of strict experiment. " <>
          "The séance weighs upon me more than I care to say, and I shall say no more " <>
          "of it for the present than that I have not forgotten the blue ribbon.",
      "valediction" => "I remain, yours faithfully,",
      "emotional_tone" => "restrained",
      "concealed_intent" =>
        "To learn what #{Cast.short_name(to)} knows while disclosing nothing.",
      "visible_claims" => ["The séance took place at Cheltenham."],
      "references" => ["the blue ribbon"],
      "private_note" => "Wrote to #{Cast.short_name(to)} and gave nothing away."
    }
  end

  defp answer(:appraise, from, _to) do
    %{
      "appraisal" => "#{Cast.short_name(from)} is holding something back.",
      "deltas" => %{"trust" => -1, "suspicion" => 1, "affection" => 0, "resentment" => 0},
      "belief_deltas" => %{"spiritualism" => 0, "theosophy" => 0, "skepticism" => 1},
      "fear_of_exposure" => 1,
      "urgency" => 1,
      "willingness_to_reveal" => 0,
      "new_pressure" => "A letter from #{Cast.short_name(from)} demands an answer."
    }
  end
end
