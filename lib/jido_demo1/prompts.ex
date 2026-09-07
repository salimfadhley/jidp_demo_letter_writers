defmodule JidoDemo1.Prompts do
  @moduledoc """
  Builds the prompts a character sends to the model.

  Every function here takes only the character's own state, so nothing from
  another agent can leak in: the only things a character knows about the
  others are its own dispositions toward them and the letters it has seen.
  """

  alias JidoDemo1.{Cast, Letter}

  @doc "The character's identity, private state and the rules of the drama."
  @spec system(map()) :: String.t()
  def system(state) do
    """
    You are #{state.public_name}, a character in an epistolary drama set in England in 1891.
    You are not an assistant. You are this person, with this person's motives and blind spots.

    ## Who you are
    Location: #{state.location}
    Social position: #{state.social_class}
    Public persona: #{state.public_persona}
    Temperament: #{Enum.join(state.temperament, "; ")}
    Spiritual position: #{state.spiritual_position}

    ## What you privately want (never state this plainly)
    #{state.private_motivation}

    ## Your guilty secret (conceal it; allude to it only obliquely, confess only under great pressure)
    #{state.guilty_secret}

    ## Your anxiety
    #{state.anxiety}

    ## What you know of the séance
    #{state.knowledge_of_event}

    ## Your beliefs (0 = none, 10 = absolute)
    #{format_map(state.belief_state)}

    ## Your feelings toward the others (-10 to 10)
    #{format_relationships(state)}

    ## Pressures weighing on you now
    #{list_or_none(state.current_pressure)}

    ## Your private recollections
    #{list_or_none(Enum.take(state.private_memory, -8))}

    ## Rules
    1. Stay in character at all times.
    2. Write late-Victorian English epistolary prose: period-flavoured but readable. No parody, no
       heavy archaism, no modern slang, therapy language or contemporary idiom.
    3. Do not reveal your secret quickly. You may lie, evade, flatter, accuse or confess as your
       motives dictate. You may misunderstand others.
    4. Every letter must advance emotional, informational or social tension, and add something new.
    5. Whether the dead truly spoke must remain ambiguous. Treat Theosophy as a fashionable,
       intellectually tempting and controversial movement of the day, not as magic.
    6. Answer only with a single JSON object, with no text before or after it. Inside JSON
       strings, write paragraph breaks as the two characters \\n\\n, never as raw line breaks.
    """
  end

  @doc "Instruction to compose a letter to `to`."
  @spec compose(map(), Cast.id(), pos_integer(), Date.t()) :: String.t()
  def compose(state, to, round, date) do
    """
    TASK: COMPOSE a letter.

    Date: #{Letter.format_date(date)}. Written from #{state.location}.
    You are writing to: #{Cast.name(to)}.
    Your disposition toward them: #{Map.get(state.dispositions, to, "none recorded")}
    This is round #{round} of the correspondence.

    ## The correspondence you have seen so far, oldest first
    #{correspondence(state)}

    Write the letter now, in the first person. Between 220 and 380 words in the body. Refer to
    what you have received where it serves you; pass on, distort, or withhold as your character
    would. Do not include the dateline, place, or your signature in the body; they are added
    for you.

    Return exactly this JSON object:
    {
      "salutation": "e.g. My dear Dr. Pembroke,",
      "body": "the letter body, paragraphs separated by blank lines",
      "valediction": "e.g. I remain, yours very sincerely,",
      "emotional_tone": one of "restrained", "pleading", "accusatory", "flirtatious", "evasive", "confessional",
      "concealed_intent": "one sentence: what you are really trying to achieve with this letter",
      "visible_claims": ["short statements of fact or accusation the letter openly makes"],
      "references": ["earlier letters, events or people this letter refers to"],
      "private_note": "one sentence you would write in your own diary about sending this letter"
    }
    """
  end

  @doc "Instruction to appraise a letter just received and report how it moved you."
  @spec appraise(map(), Letter.t()) :: String.t()
  def appraise(state, %Letter{} = letter) do
    """
    TASK: APPRAISE a letter you have just received.

    From: #{Cast.name(letter.from)}, dated #{Letter.format_date(letter.date)}.
    Your disposition toward them: #{Map.get(state.dispositions, letter.from, "none recorded")}

    ---
    #{Letter.to_text(letter)}
    ---

    Read it as yourself. Decide privately what it does to your trust, suspicion, affection and
    resentment toward the writer, to your beliefs, and to your own fear, urgency and readiness
    to reveal what you are hiding. Every delta must be an integer from -2 to 2.

    Return exactly this JSON object:
    {
      "appraisal": "one or two sentences of private reaction, in your own voice",
      "deltas": {"trust": 0, "suspicion": 0, "affection": 0, "resentment": 0},
      "belief_deltas": {"spiritualism": 0, "theosophy": 0, "skepticism": 0},
      "fear_of_exposure": 0,
      "urgency": 0,
      "willingness_to_reveal": 0,
      "new_pressure": "one short sentence naming the new pressure this letter puts on you, or empty"
    }
    """
  end

  defp correspondence(%{public_memory: []}), do: "(none yet)"

  defp correspondence(state) do
    state.public_memory
    |> Enum.take(-8)
    |> Enum.map_join("\n\n", fn letter ->
      letter = Letter.to_struct(letter)

      heading =
        if letter.from == state.character_id,
          do: "[You wrote to #{Cast.name(letter.to)}, #{Letter.format_date(letter.date)}]",
          else: "[From #{Cast.name(letter.from)}, #{Letter.format_date(letter.date)}]"

      "#{heading}\n#{letter.salutation}\n\n#{String.trim(letter.body)}\n\n#{letter.valediction}"
    end)
  end

  defp format_relationships(state) do
    Enum.map_join(state.relationships, "\n", fn {other, values} ->
      "- #{Cast.name(other)}: #{format_map(values)}. #{Map.get(state.dispositions, other, "")}"
    end)
  end

  defp format_map(map) do
    map
    |> Enum.sort()
    |> Enum.map_join(", ", fn {k, v} -> "#{k} #{v}" end)
  end

  defp list_or_none([]), do: "(none)"
  defp list_or_none(items), do: Enum.map_join(items, "\n", &"- #{&1}")
end
