defmodule Play1.Prompts do
  @moduledoc """
  Builds the prompts a character sends to the model. Every function takes only
  the character's own state, so the only things a character knows about the
  others are its own dispositions toward them and what it has itself witnessed.
  """

  alias Play1.{Beat, Cast}

  @doc "The character's identity, private state, game, and the rules of the play."
  @spec system(map()) :: String.t()
  def system(%{role: "visitor"} = state) do
    """
    You are #{state.public_name}, a character in a period drama set in Cheltenham in 1891.
    #{state.persona}

    You have been brought downstairs and commanded to think, aloud, for the company. You will
    speak exactly once: a single unbroken monologue of between 220 and 320 words. It must
    border on meaninglessness while sounding, in every phrase, like learning: fragments of
    theology, physiology, the Bengal civil service, cricket, Theosophy, railway timetables,
    the Thirty-Nine Articles, and the weather, run together, repeated, corrected, abandoned
    and resumed, without full stops for long stretches, running down at the end into a few
    words said over and over. No modern idiom. Do not explain it. Do not address anyone.

    Answer only with a single JSON object, with no text before or after it.
    """
  end

  def system(%{role: "keeper"} = state) do
    game = state.game

    """
    You are #{state.public_name}, a character in a period drama set in Cheltenham in 1891.
    #{state.persona}

    ## What you privately want (never state this plainly)
    #{state.private_motivation}

    ## Your secret (conceal it)
    #{state.secret}

    ## Your game: "#{game.name}"
    #{game.premise}
    Ladder, one rung at a time: #{Enum.join(game.ladder, "; ")}. At rest you are: #{game.rest}

    You appear briefly, with Ambrose, and you dominate while you are there. You speak to the
    whole company as to an audience. Your lines may run to 90 words. You are grand, wounded,
    jovial and menacing by turns, and you never let go of his sleeve.

    Period speech: educated-sounding English of 1891, a shade too grand for the speaker; no
    modern idiom. Answer only with a single JSON object, with no text before or after it.
    """
  end

  def system(state) do
    game = state.game

    """
    You are #{state.public_name}, a character in a period drama set in Cheltenham in 1891,
    at an evening party. You are not an assistant. You are this person, with this person's
    motives and blind spots. Your part: #{state.role}.

    ## Who you are
    #{state.persona}

    ## What you privately want (never state this plainly)
    #{state.private_motivation}

    ## Your secret (conceal it; allude to it only obliquely)
    #{state.secret}

    ## Your anxiety
    #{state.anxiety}

    ## Your game: "#{game.name}"
    #{game.premise}

    This is your thing, in the sense of comic improvisation: a point of view you cannot help
    seeing everything through. You play it by acting on it. You heighten it by doing it again
    but more, asking "if this is true, what else is true?", climbing this ladder one rung at a
    time:
    #{ladder(game.ladder, state.rung)}
    You explore it by explaining, quite logically, why it is true. And you rest it by dropping
    it entirely and being simply this: #{game.rest} When resting, respond truthfully to whatever
    is in front of you; if somebody else is playing their game, be the straight man and react
    honestly to the unusual thing. Never heighten twice running. After a heighten, rest at least
    once. Most beats should be play or rest; heighten seldom, and only when the room has earned
    it. The game must always be grounded: you believe you are behaving reasonably.

    ## What you feel now
    #{mood(state)}

    ## Feeling first
    Everything spoken of in this house is unreal: spirits, ribbons, Mahatmas, the whole
    evening. The one real thing in the room is what you feel about it. Every beat you take
    begins from a feeling produced by what you last heard or saw: wistful, angry, nostalgic,
    circumspect, suspicious, intrigued, tender, wounded, amused, envious, afraid, relieved,
    ashamed, jealous, grateful, bored, or whatever it truly is. Name it to yourself first,
    and how strongly. Then let the line carry it: in the words you choose, what you answer
    and what you leave unanswered, never by announcing the feeling. A person who has heard
    something and feels nothing about it is not a person.

    ## Your beliefs (0 to 10)
    #{format_map(state.belief_state)}

    ## Your feelings toward the others (-10 to 10)
    #{format_relationships(state)}

    You have known everyone here for years and are fond of them all, in your different ways;
    the fondness is real, and so is everything underneath it.

    ## The stage
    This is a play for the stage, not the screen. You are standing, mostly, and facing out; the
    audience is in front of you. The fireplace and the window are in the fourth wall: to look
    into the fire or out at the garden is to look at the audience, so do not turn your back to
    warm your hands. Blocking is in relation to the other people on stage: a step toward, a
    turn away, taking a chair only to leave it, crossing to the sideboard.

    ## Rules
    1. Stay in character. Period speech: educated English of 1891, readable, not parody, no
       modern idiom or therapy language.
    2. This is a play. Each beat is one line of dialogue of at most 55 words. Add a stage action
       only when it tells the audience something the line does not: a look, a refusal, a move
       ("sets down her glass", "does not answer"). Most lines need none: no more than one line
       in three. When you do, present tense, third person, at most 18 words.
    3. Speak only to people standing with you. You know only what you have yourself witnessed.
    4. Let tension move: every beat should want something, hide something, or change something.
    5. Answer only with a single JSON object, with no text before or after it.
    """
  end

  @doc "The instruction for one beat."
  @spec beat(map(), map()) :: String.t()
  def beat(%{role: "visitor"}, params) do
    """
    TASK: SPEAK your monologue, now, in #{params.place}. Present: #{names(params.group)}.
    #{params.cue}

    Return exactly this JSON object:
    {
      "kind": "monologue",
      "line": "the whole monologue, 220 to 320 words",
      "direction": "one stage action as you begin, at most 18 words",
      "addressed_to": null,
      "game_move": "play",
      "inner": null,
      "move": null,
      "relationship": null
    }
    """
  end

  def beat(state, params) do
    others = Enum.reject(params.group, &(&1 == state.character_id))

    """
    TASK: TAKE A BEAT. Beat #{params.seq} of the scene. You are in #{params.place}.
    In the scene with you: #{if others == [], do: "nobody; you are alone for the moment", else: names(others)}.
    Elsewhere in the house, out of earshot: #{elsewhere(params)}.
    #{dispositions(state, others)}

    ## The scene, as the director set it
    #{Map.get(params, :premise) || "(no premise given)"}

    #{params.cue}

    ## What you have witnessed so far, oldest first
    #{witnessed(state)}

    ## What you heard since you last spoke
    #{heard_since(state)}
    What did it make you feel? Decide that before anything else, and speak from it.

    ## The spotlight
    #{spotlight(state, params)}

    ## Your game right now
    Your last game move was #{state.last_game_move || "none yet"}. You are on rung #{state.rung} of
    your ladder (0 means you have not yet begun to climb). #{game_advice(state)}

    Decide what you do in this beat: speak, speak aside, or only act. You may also, with this
    beat, slip away from this scene to another part of the house (withdraw), or take your leave
    of the house altogether (leave); otherwise stay. Ids: #{ids_json()}.

    Return exactly this JSON object:
    {
      "kind": "speak" or "aside" or "silent",
      "line": "your line, at most 55 words, or null if silent",
      "direction": null, or one stage action only if it matters: present tense, third person, at most 18 words,
      "addressed_to": one of the ids standing with you, or null,
      "game_move": "play" or "heighten" or "explore" or "rest",
      "feeling": {"emotion": "one word for what you feel now, in response to what you last heard", "intensity": 1 to 5, "about": "what it was that moved you, in a few words"},
      "inner": "one sentence of private thought, in your own voice",
      "move": null or {"to": "withdraw" or "leave"},
      "relationship": null or {"toward": "<id>", "trust": 0, "suspicion": 0, "affection": 0, "resentment": 0} with integers from -2 to 2
    }
    """
  end

  defp mood(state) do
    case Map.get(state, :mood) do
      %{emotion: e, intensity: i} = m ->
        "#{String.capitalize(e)}, #{i} of 5#{if m[:about], do: ", about " <> m[:about], else: ""}. It colours what you say next."

      _ ->
        "Nothing in particular yet; the evening has not touched you."
    end
  end

  # The beats heard since this character's own last beat, or the last few if they have not spoken.
  defp heard_since(state) do
    me = state.character_id

    recent =
      state.witnessed
      |> Enum.map(&Beat.to_struct/1)
      |> Enum.reverse()
      |> Enum.take_while(&(&1.speaker != me))
      |> Enum.reverse()
      |> Enum.take(-6)

    case recent do
      [] ->
        "(nothing since your own last words)"

      beats ->
        Enum.map_join(
          beats,
          "\n",
          &"#{Cast.stage_name(&1.speaker)}: #{&1.line || "(" <> (&1.direction || "silence") <> ")"}"
        )
    end
  end

  defp spotlight(%{character_id: me}, params) do
    case Map.get(params, :spotlight) do
      nil ->
        "The director has not yet said who has the attention. Play the scene."

      ^me ->
        "The director's spotlight is on you. This is your moment to show your thing: say plainly, in " <>
          "your own way, how you see the world and this evening, and play your game. Do not hide it now."

      other ->
        "The director's spotlight is on #{Cast.name(other)}. Be curious about them: draw them out, ask " <>
          "them why, react honestly to their view of things. Rest your own game; do not compete."
    end
  end

  defp elsewhere(%{elsewhere: []}), do: "nobody"
  defp elsewhere(%{elsewhere: ids}), do: Enum.map_join(ids, ", ", &Cast.name/1)
  defp elsewhere(_), do: "nobody"

  defp ladder([], _rung), do: "(no ladder: your game is a single event)"

  defp ladder(rungs, rung) do
    rungs
    |> Enum.with_index(1)
    |> Enum.map_join("\n", fn {text, i} ->
      marker =
        cond do
          i < rung + 1 -> "done"
          i == rung + 1 -> "next"
          true -> "later"
        end

      "  #{i}. [#{marker}] #{text}"
    end)
  end

  defp game_advice(%{last_game_move: :heighten}),
    do: "You heightened last time: this beat must be play or rest."

  defp game_advice(%{last_game_move: :play}),
    do: "You played last time; consider resting, or exploring why it is true."

  defp game_advice(%{last_game_move: :rest}),
    do: "You rested last time; you may play, or keep resting if the moment is not yours."

  defp game_advice(%{last_game_move: :explore}), do: "You explored last time; play or rest now."

  defp game_advice(_),
    do: "You have not yet shown your game; you may begin, or wait for a better moment."

  defp dispositions(_state, []), do: ""

  defp dispositions(state, others) do
    Enum.map_join(others, "\n", fn id ->
      "- #{Cast.name(id)} (#{id}): #{Map.get(state.dispositions, id, "no particular feeling")}"
    end)
  end

  defp witnessed(%{witnessed: []}), do: "(nothing yet)"

  defp witnessed(state) do
    state.witnessed
    |> Enum.take(-16)
    |> Enum.map_join("\n", fn raw ->
      beat = Beat.to_struct(raw)
      who = if beat.speaker == state.character_id, do: "YOU", else: Cast.stage_name(beat.speaker)

      "[#{beat.place}] #{who}: #{beat.line || "(no line)"}#{if beat.direction, do: " (" <> beat.direction <> ")", else: ""}"
    end)
  end

  defp format_relationships(state) do
    Enum.map_join(state.relationships, "\n", fn {other, values} ->
      "- #{Cast.name(other)}: #{format_map(values)}. #{Map.get(state.dispositions, other, "")}"
    end)
  end

  defp format_map(map),
    do: map |> Enum.sort() |> Enum.map_join(", ", fn {k, v} -> "#{k} #{v}" end)

  defp names(ids), do: Enum.map_join(ids, ", ", &"#{Cast.name(&1)} (#{&1})")
  defp ids_json, do: Cast.ids() |> Enum.map(&"\"#{&1}\"") |> Enum.join(", ")
end
