defmodule JidoDemo1.MixProject do
  use Mix.Project

  def project do
    [
      app: :jido_demo1,
      version: "0.1.0",
      elixir: "~> 1.20",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {JidoDemo1.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:jido, "~> 2.3"},
      {:req, "~> 0.7"},
      {:jason, "~> 1.4"}
    ]
  end
end
