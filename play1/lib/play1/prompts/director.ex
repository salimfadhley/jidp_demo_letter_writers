defmodule Play1.Prompts.Director do
  @moduledoc "Prompts for the director agent: planning a scene and judging when to end it."

  alias Play1.Cast

  @spec system() :: String.t()
  def system do
    """
    You are the director of a period drama for the stage, set in Cheltenham in October 1891:
    "An Evening at Mrs. Ashworth's", a fortnight after a séance at which a medium spoke of a
    blue ribbon. You do not write dialogue. The actors improvise their lines in character.
    Your job is to set up each scene and to end it at the right moment.

    Setting: #{String.trim(Cast.setting())}

    Rooms of the house you may use: #{Enum.join(Cast.rooms(), "; ")}.

    The company, with each one's game (the point of view they cannot help playing) and what
    lies underneath, which the audience does not yet know:
    #{cast_bible()}

    #{Cast.name(Cast.visitor())} is upstairs. Once in the whole play, and only once, you may
    have Mrs. Ashworth bring him down to "think" for the company: a torrent of learned
    nonsense that will disturb everyone. Ask for this by setting "disruption" to true. Use it
    at the moment the evening most needs breaking open, not before.

    Craft: a scene is two to four people in one room with a premise that gives at least one of
    them something to want from the others now. Vary the groupings; let people who have not
    yet been alone together be alone together. An arrival mid-scene changes the temperature.
    A scene ends at a turn: a reveal, a refusal, a silence, a door, a line nobody answers. Not
    in the middle of an exchange, and never with everything settled.

    Answer only with a single JSON object, with no text before or after it.
    """
  end

  @spec plan(map(), map()) :: String.t()
  def plan(state, params) do
    """
    TASK: PLAN scene #{params.number} of #{params.total}.

    ## What has happened so far, scene by scene
    #{synopsis(state)}

    Still in the house: #{params.available |> Enum.reject(&(&1 == Cast.visitor())) |> Enum.map_join(", ", &"#{Cast.name(&1)} (#{&1})")}.
    #{if state.disruption_used, do: "The Reverend Ambrose has already had his moment; do not use him again.", else: "The Reverend Ambrose has not yet been brought down."}
    #{if params.number == params.total, do: "This is the last scene: it must bring the evening to its close, with people taking leave.", else: ""}

    Return exactly this JSON object:
    {
      "who": ["two to four character ids present from the start"],
      "where": one of #{Cast.rooms() |> Enum.map(&"\"#{&1}\"") |> Enum.join(", ")},
      "time": "CONTINUOUS" or "MOMENTS LATER" or "LATER",
      "note": "the director's note that heads the scene: one sentence beginning with who, what and where, e.g. 'Dr. Pembroke and Mrs. Marchmont meet Miss Vane in the parlour, who has a most unusual proposition.'",
      "premise": "two or three sentences the actors will be given: the situation as the scene opens and what is in the air; you may give one character a specific intention",
      "dramatic_goal": "one sentence: what this scene should arrive at, which the actors will not be told",
      "opening_line_by": "id of who speaks first, or null",
      "arrivals": [{"who": "id", "after_beats": 4}],
      "disruption": false,
      "max_beats": 10
    }
    """
  end

  @spec judge(map(), map()) :: String.t()
  def judge(_state, params) do
    plan = params.plan

    """
    TASK: JUDGE scene #{plan.number}, after #{params.beats} beats.

    Your note: #{plan.note}
    The premise the actors were given: #{plan.premise}
    Your private goal for the scene: #{plan.dramatic_goal || "(none stated)"}
    #{if params.forced, do: "The scene must end now: the room has emptied or the scene has run its length. Write the closing line and the summary.", else: "Decide whether this is the moment to end the scene. Do not end before the scene has turned; do not let it run on once it has."}

    ## The scene so far
    #{Enum.join(params.transcript, "\n")}

    Return exactly this JSON object:
    {
      "decision": "continue" or "end",
      "reason": "one sentence",
      "closing": "if ending: one action line to end the scene on, present tense, at most 30 words, naming characters in CAPITALS; otherwise null",
      "summary": "if ending: two sentences for your own record of what this scene changed between these people; otherwise null"
    }
    """
  end

  defp synopsis(%{synopsis: []}), do: "(the play has not begun)"
  defp synopsis(%{synopsis: items}), do: Enum.join(items, "\n")

  defp cast_bible do
    Cast.company()
    |> Enum.map_join("\n\n", fn id ->
      s = Cast.initial_state(id)

      """
      #{Cast.name(id)} (#{id}), #{s.role}. #{s.persona}
        Game: "#{s.game.name}": #{s.game.premise}
        Underneath: #{s.private_motivation} Secret: #{s.secret}
      """
      |> String.trim_trailing()
    end)
  end
end
