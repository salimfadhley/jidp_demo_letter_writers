defmodule JidoDemo1.Actions.ReceiveLetter do
  @moduledoc """
  Take in a letter: remember it, react to it privately, and adjust relationship,
  belief and pressure state accordingly.

  The letter is stored in public memory before the model is consulted, so a
  failed appraisal never loses the correspondence itself.
  """

  use Jido.Action,
    name: "receive_letter",
    description: "Record a received letter and update private state in reaction to it",
    schema: [
      letter: [type: :any, required: true, doc: "The public form of the letter"]
    ]

  require Logger

  alias Jido.Agent.Directive
  alias Jido.Signal
  alias JidoDemo1.{Appraisal, Cast, Letter, LLM, Prompts}

  @impl true
  def run(%{letter: raw}, %{state: state}) do
    letter = Letter.public(raw)
    me = state.character_id
    remembered = %{public_memory: state.public_memory ++ [letter]}
    state_with_letter = Map.merge(state, remembered)

    Logger.info(
      "#{state.public_name} receives letter #{letter.id} from #{Cast.name(letter.from)}"
    )

    system = Prompts.system(state_with_letter)
    user = Prompts.appraise(state_with_letter, letter)

    case LLM.complete_json(system, user, kind: :appraise, from: letter.from, to: me) do
      {:ok, json} ->
        appraisal = Appraisal.from_model(json, letter.from, letter.id)
        changes = Appraisal.apply(appraisal, state_with_letter)

        new_state =
          remembered
          |> Map.merge(changes)
          |> Map.put(:last_appraisal, appraisal)
          |> Map.put(:private_memory, state.private_memory ++ [private_note(letter, appraisal)])

        {:ok, new_state,
         notify(state, "letter.appraised", %{character: me, appraisal: appraisal})}

      {:error, reason} ->
        Logger.error("#{state.public_name} could not appraise a letter: #{inspect(reason)}")

        {:ok, remembered,
         notify(state, "letter.failed", %{character: me, seq: nil, reason: inspect(reason)})}
    end
  end

  defp private_note(letter, appraisal) do
    "#{Letter.format_date(letter.date)}, on a letter from #{Cast.name(letter.from)}: #{appraisal.note}"
  end

  defp notify(%{observer: nil}, _type, _data), do: []

  defp notify(state, type, data) do
    signal = Signal.new!(type, data, source: "/character/#{state.character_id}")
    [%Directive.Emit{signal: signal, dispatch: {:pid, [target: state.observer]}}]
  end
end
