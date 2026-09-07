defmodule JidoDemo1.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      JidoDemo1.Jido
    ]

    opts = [strategy: :one_for_one, name: JidoDemo1.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
