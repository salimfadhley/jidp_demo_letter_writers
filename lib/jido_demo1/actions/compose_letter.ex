defmodule JidoDemo1.Actions.ComposeLetter do
  @moduledoc """
  Write a letter in character and send it.

  The full letter, including concealed intent, goes into the sender's own
  memory and to the observer. Only the public form is delivered to the
  recipient agent.
  """

  use Jido.Action,
    name: "compose_letter",
    description: "Compose a letter to a chosen or given recipient and dispatch it",
    schema: [
      to: [type: {:or, [:atom, nil]}, doc: "Recipient; when absent the character chooses"],
      seq: [type: :pos_integer, required: true, doc: "Position in the whole correspondence"],
      round: [type: :pos_integer, required: true],
      date: [type: :string, required: true, doc: "ISO 8601 date of writing"]
    ]

  require Logger

  alias Jido.Agent.Directive
  alias Jido.Signal
  alias JidoDemo1.Actions.ChooseCorrespondent
  alias JidoDemo1.{Cast, Letter, LLM, Prompts}

  @impl true
  def run(params, %{state: state}) do
    to = Map.get(params, :to) || state.next_recipient || ChooseCorrespondent.choose(state)
    date = Date.from_iso8601!(params.date)
    me = state.character_id

    Logger.info("#{state.public_name} composes letter #{params.seq} to #{Cast.name(to)}")

    system = Prompts.system(state)
    user = Prompts.compose(state, to, params.round, date)

    case LLM.complete_json(system, user, kind: :compose, from: me, to: to) do
      {:ok, json} ->
        letter =
          Letter.from_model(json,
            id: "letter-#{String.pad_leading(Integer.to_string(params.seq), 3, "0")}",
            round: params.round,
            from: me,
            to: to,
            date: date
          )

        public = Letter.public(letter)

        new_state = %{
          last_letter: letter,
          last_recipient: to,
          next_recipient: nil,
          letters_sent: state.letters_sent + 1,
          public_memory: state.public_memory ++ [public],
          private_memory: state.private_memory ++ [private_note(letter)]
        }

        {:ok, new_state, deliver(letter, public, state)}

      {:error, reason} ->
        Logger.error("#{state.public_name} could not compose a letter: #{inspect(reason)}")
        {:ok, %{}, failure(state, params.seq, reason)}
    end
  end

  defp private_note(%Letter{} = letter) do
    note = letter.private_note || "Wrote to #{Cast.name(letter.to)}."
    "#{Letter.format_date(letter.date)}: #{note}"
  end

  defp deliver(letter, public, state) do
    source = "/character/#{state.character_id}"

    to_recipient =
      case JidoDemo1.Jido.whereis(Cast.agent_id(letter.to)) do
        nil ->
          []

        pid ->
          signal = Signal.new!("letter.received", %{letter: public}, source: source)
          [%Directive.Emit{signal: signal, dispatch: {:pid, [target: pid]}}]
      end

    to_observer =
      case state.observer do
        nil ->
          []

        pid ->
          signal = Signal.new!("letter.sent", %{letter: letter}, source: source)
          [%Directive.Emit{signal: signal, dispatch: {:pid, [target: pid]}}]
      end

    to_recipient ++ to_observer
  end

  defp failure(%{observer: nil}, _seq, _reason), do: []

  defp failure(state, seq, reason) do
    signal =
      Signal.new!(
        "letter.failed",
        %{character: state.character_id, seq: seq, reason: inspect(reason)},
        source: "/character/#{state.character_id}"
      )

    [%Directive.Emit{signal: signal, dispatch: {:pid, [target: state.observer]}}]
  end
end
