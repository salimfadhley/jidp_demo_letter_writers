defmodule JidoDemo1.Actions.WriteLetter do
  @moduledoc """
  Compose a letter in character and pass the story along.

  On receipt of a letter (or, for the first letter, a premise) the action asks
  OpenRouter for a reply in the character's voice, appends it to the story file,
  and emits a `letter.received` signal to the next correspondent in the ring and
  to the observer that is waiting for the story to finish.
  """

  use Jido.Action,
    name: "write_letter",
    description: "Write a letter in character and forward it",
    schema: [
      from: [type: :string, doc: "Name of the sender; absent for the opening premise"],
      body: [type: :string, required: true, doc: "The letter text, or the premise"],
      number: [
        type: :non_neg_integer,
        required: true,
        doc: "Sequence number of the received letter"
      ]
    ]

  require Logger

  alias Jido.Agent.Directive
  alias Jido.Signal
  alias JidoDemo1.{LetterFile, OpenRouter}

  @impl true
  def run(params, %{state: state, agent: agent}) do
    from = Map.get(params, :from)
    history = state.history ++ received_entry(from, params.body)
    my_number = params.number + 1

    Logger.info("#{state.name} is composing letter #{my_number} to #{state.next_name}")

    case OpenRouter.chat(system_prompt(state), [
           %{role: "user", content: user_prompt(state, from, params.body, history)}
         ]) do
      {:ok, letter} ->
        LetterFile.append(state.letter_path, my_number, state.name, state.next_name, letter)

        signal =
          Signal.new!(
            "letter.received",
            %{from: state.name, body: letter, number: my_number},
            source: "/correspondent/#{agent.id}"
          )

        new_state = %{
          history: history ++ [%{kind: :sent, counterpart: state.next_name, body: letter}],
          letters_written: state.letters_written + 1
        }

        {:ok, new_state, [%Directive.Emit{signal: signal, dispatch: targets(state, my_number)}]}

      {:error, reason} ->
        signal =
          Signal.new!(
            "letter.failed",
            %{from: state.name, number: my_number, reason: inspect(reason)},
            source: "/correspondent/#{agent.id}"
          )

        {:ok, %{}, [%Directive.Emit{signal: signal, dispatch: {:pid, [target: state.observer]}}]}
    end
  end

  defp received_entry(nil, _premise), do: []
  defp received_entry(from, body), do: [%{kind: :received, counterpart: from, body: body}]

  # Always tell the observer; only pass the letter on while the story has room.
  defp targets(state, my_number) do
    observer = {:pid, [target: state.observer]}

    if my_number < state.max_letters do
      [observer, {:pid, [target: JidoDemo1.Jido.whereis(state.next_id)]}]
    else
      [observer]
    end
  end

  defp system_prompt(state) do
    """
    You are #{state.name}, #{state.persona}

    Your acquaintances, with whom letters circulate:
    #{state.acquaintances}

    The year is 1887. You are writing a private letter in English, in the voice and idiom of
    the period, in the first person. The letter must be funny: dry, character-driven comedy
    arising from your preoccupations, misunderstandings and self-regard. Never wink at the
    reader, never use anachronism, never explain the joke. Keep it between 180 and 260 words.
    Begin with a dateline and salutation and end with a sign-off in your own name.
    Output only the letter text, with no commentary before or after it.
    """
  end

  defp user_prompt(state, nil, premise, _history) do
    """
    Nobody has written to you yet. Open the correspondence by writing to #{state.next_name}.

    The occasion for writing: #{premise}
    """
  end

  defp user_prompt(state, from, body, history) do
    earlier =
      history
      |> Enum.drop(-1)
      |> Enum.take(-6)
      |> Enum.map_join("\n\n", fn
        %{kind: :received, counterpart: c, body: b} -> "[Received from #{c}]\n#{b}"
        %{kind: :sent, counterpart: c, body: b} -> "[You wrote to #{c}]\n#{b}"
      end)

    """
    You have just received this letter from #{from}:

    ---
    #{body}
    ---

    Your earlier correspondence, oldest first:

    #{if earlier == "", do: "(none)", else: earlier}

    Now write your next letter, to #{state.next_name}. Pass on, react to, embellish or
    misreport what you have just learned, exactly as your character would. Move the story
    forward: add a new complication of your own rather than merely restating events.
    """
  end
end
