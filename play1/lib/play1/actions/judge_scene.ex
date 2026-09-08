defmodule Play1.Actions.JudgeScene do
  @moduledoc """
  The director watches the scene and decides whether it has reached the moment
  to end. On ending, it writes the closing action line and records, for its own
  synopsis, what the scene changed.
  """

  use Jido.Action,
    name: "judge_scene",
    description: "Decide whether the scene should end now, and how",
    schema: [
      plan: [type: :any, required: true],
      transcript: [type: {:list, :string}, required: true],
      beats: [type: :non_neg_integer, required: true],
      min_beats: [type: :pos_integer, default: 8],
      forced: [
        type: :boolean,
        default: false,
        doc: "The scene has emptied or hit its limit; it must end"
      ]
    ]

  require Logger

  alias Jido.Agent.Directive
  alias Jido.Signal
  alias Play1.{LLM, Prompts}

  @type verdict :: %{
          decision: :continue | :end,
          reason: String.t() | nil,
          closing: String.t() | nil,
          summary: String.t() | nil
        }

  @impl true
  def run(params, %{state: state}) do
    plan = params.plan

    case LLM.complete_json(Prompts.Director.system(), Prompts.Director.judge(state, params),
           kind: :judge,
           number: plan.number,
           beats: params.beats,
           present: params.present,
           forced: params.forced
         ) do
      {:ok, json} ->
        verdict = parse(json, params)

        new_state =
          if verdict.decision == :end do
            %{
              verdicts: state.verdicts ++ [verdict],
              synopsis:
                state.synopsis ++ ["Scene #{plan.number}: #{verdict.summary || plan.premise}"]
            }
          else
            %{verdicts: state.verdicts ++ [verdict]}
          end

        {:ok, new_state, notify(state, "scene.judged", %{number: plan.number, verdict: verdict})}

      {:error, reason} ->
        Logger.error("The director could not judge the scene: #{inspect(reason)}")
        {:ok, %{}, notify(state, "scene.failed", %{number: plan.number, reason: inspect(reason)})}
    end
  end

  @spec parse(map(), map()) :: verdict()
  def parse(json, params) do
    thing_shown = json["thing_shown"] == true
    revealed = Map.get(params, :revealed, [])

    # A scene may not end before at least one character's thing has been shown.
    decision =
      cond do
        params.forced -> :end
        params.beats < params.min_beats -> :continue
        revealed == [] and not thing_shown -> :continue
        to_string(json["decision"] || "") |> String.downcase() == "end" -> :end
        true -> :continue
      end

    spotlight =
      case Play1.Cast.parse_id(json["spotlight"]) do
        nil -> params.spotlight
        id -> if id in params.present, do: id, else: params.spotlight
      end

    %{
      decision: decision,
      spotlight: spotlight,
      thing_shown: thing_shown,
      reason: text(json["reason"]),
      closing: text(json["closing"]),
      summary: text(json["summary"])
    }
  end

  defp text(v) when is_binary(v) do
    case String.trim(v) do
      "" -> nil
      t -> t
    end
  end

  defp text(_), do: nil

  defp notify(%{observer: nil}, _type, _data), do: []

  defp notify(state, type, data) do
    [
      %Directive.Emit{
        signal: Signal.new!(type, data, source: "/director"),
        dispatch: {:pid, [target: state.observer]}
      }
    ]
  end
end
