defmodule Play1.Director do
  @moduledoc """
  The director as a Jido agent. It sets up each scene (who, what, where) and
  decides when a scene should end. It sees the public script as an audience
  would, and keeps its own synopsis of what each scene changed; it never sees
  a character's private state.

  Signals:

  - `scene.plan` routes to `Play1.Actions.PlanScene`
  - `scene.judge` routes to `Play1.Actions.JudgeScene`
  """

  use Jido.Agent,
    name: "director",
    description: "Sets up scenes and ends them at the right moment",
    schema: [
      synopsis: [type: {:list, :string}, default: []],
      plans: [type: {:list, :any}, default: []],
      verdicts: [type: {:list, :any}, default: []],
      disruption_used: [type: :boolean, default: false],
      observer: [type: {:or, [:pid, nil]}, default: nil]
    ],
    signal_routes: [
      {"scene.plan", Play1.Actions.PlanScene},
      {"scene.judge", Play1.Actions.JudgeScene}
    ]
end
