defmodule Play1.Actions.PlanScene do
  @moduledoc "The director sets up the next scene: who, what, where, and how it may grow."

  use Jido.Action,
    name: "plan_scene",
    description: "Plan the next scene from the synopsis so far",
    schema: [
      number: [type: :pos_integer, required: true],
      total: [type: :pos_integer, required: true],
      available: [type: {:list, :atom}, required: true, doc: "Characters still in the house"]
    ]

  require Logger

  alias Jido.Agent.Directive
  alias Jido.Signal
  alias Play1.{LLM, Plan, Prompts}

  @impl true
  def run(params, %{state: state}) do
    Logger.info("The director plans scene #{params.number} of #{params.total}")

    case LLM.complete_json(Prompts.Director.system(), Prompts.Director.plan(state, params),
           kind: :plan,
           number: params.number,
           total: params.total,
           available: params.available,
           disruption_used: state.disruption_used
         ) do
      {:ok, json} ->
        plan = Plan.from_model(json, params.number, params.available)
        plan = if state.disruption_used, do: %{plan | disruption: false}, else: plan

        new_state = %{
          plans: state.plans ++ [plan],
          disruption_used: state.disruption_used or plan.disruption
        }

        {:ok, new_state, notify(state, "scene.planned", %{plan: plan})}

      {:error, reason} ->
        Logger.error("The director could not plan a scene: #{inspect(reason)}")

        {:ok, %{},
         notify(state, "scene.failed", %{number: params.number, reason: inspect(reason)})}
    end
  end

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
