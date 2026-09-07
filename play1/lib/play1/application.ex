defmodule Play1.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      Play1.Jido
    ]

    opts = [strategy: :one_for_one, name: Play1.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
