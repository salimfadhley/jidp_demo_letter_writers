defmodule Play1.Actions.TakeBeat do
  @moduledoc """
  Perform one beat: ask the model, in character, for a line and an action,
  apply the game discipline (no heightening twice running), remember the beat,
  and report it to the director. The recipient agents hear only the public form,
  delivered by the director, because only the director knows who was standing there.
  """

  use Jido.Action,
    name: "take_beat",
    description: "Speak a line and/or perform an action in the current group",
    schema: [
      seq: [type: :pos_integer, required: true],
      phase: [type: :atom, required: true],
      place: [type: :string, required: true],
      group: [type: {:list, :atom}, required: true],
      elsewhere: [type: {:list, :atom}, default: []],
      cue: [type: :string, default: ""]
    ]

  require Logger

  alias Jido.Agent.Directive
  alias Jido.Signal
  alias Play1.{Beat, LLM, Prompts}

  @impl true
  def run(params, %{state: state}) do
    me = state.character_id
    Logger.info("#{state.public_name} takes beat #{params.seq} at #{params.place}")

    case LLM.complete_json(Prompts.system(state), Prompts.beat(state, params),
           kind: :beat,
           from: me,
           group: params.group,
           seq: params.seq,
           phase: params.phase
         ) do
      {:ok, json} ->
        beat =
          json
          |> Beat.from_model(
            seq: params.seq,
            phase: params.phase,
            speaker: me,
            place: params.place,
            group: params.group,
            rung: state.rung
          )
          |> discipline(state)

        new_state = %{
          witnessed: Enum.take(state.witnessed ++ [Beat.public(beat)], -40),
          beats_spoken: state.beats_spoken + 1,
          last_game_move: beat.game_move,
          rung: beat.rung,
          relationships: apply_relationship(state.relationships, beat.relationship)
        }

        {:ok, new_state, notify(state, "beat.taken", %{beat: beat})}

      {:error, reason} ->
        Logger.error("#{state.public_name} could not take a beat: #{inspect(reason)}")

        {:ok, %{},
         notify(state, "beat.failed", %{character: me, seq: params.seq, reason: inspect(reason)})}
    end
  end

  # The game discipline the prompt asks for, enforced: never heighten twice
  # running; a heighten climbs one rung, never past the top of the ladder.
  defp discipline(%Beat{} = beat, state) do
    ladder = length(state.game.ladder)

    case {beat.game_move, state.last_game_move} do
      {:heighten, :heighten} -> %{beat | game_move: :play}
      {:heighten, _} when state.rung >= ladder and ladder > 0 -> %{beat | game_move: :play}
      {:heighten, _} -> %{beat | rung: state.rung + 1}
      _ -> beat
    end
  end

  defp apply_relationship(relationships, nil), do: relationships

  defp apply_relationship(relationships, %{toward: toward} = delta) do
    Map.update(relationships, toward, %{}, fn current ->
      Enum.reduce([:trust, :suspicion, :affection, :resentment], current, fn key, acc ->
        Map.update(acc, key, 0, fn v -> (v + Map.get(delta, key, 0)) |> max(-10) |> min(10) end)
      end)
    end)
  end

  defp notify(%{observer: nil}, _type, _data), do: []

  defp notify(state, type, data) do
    signal = Signal.new!(type, data, source: "/character/#{state.character_id}")
    [%Directive.Emit{signal: signal, dispatch: {:pid, [target: state.observer]}}]
  end
end
