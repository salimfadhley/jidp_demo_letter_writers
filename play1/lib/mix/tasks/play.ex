defmodule Mix.Tasks.Play do
  @shortdoc "Perform An Evening at Mrs. Ashworth's"

  @moduledoc """
      mix play                 # forty beats
      mix play --beats 56
      mix play --stub          # canned model, instant
      mix play --out script.txt
  """

  use Mix.Task

  @impl true
  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args,
        strict: [beats: :integer, stub: :boolean, out: :string, timeout: :integer]
      )

    if opts[:stub], do: Application.put_env(:play1, :llm_client, Play1.LLM.Stub)
    Mix.Task.run("app.start")

    case Play1.Stage.run(Keyword.take(opts, [:beats, :out, :timeout])) do
      {:ok, result} ->
        Mix.shell().info(Play1.Report.debug_section(result.entries))
        Mix.shell().info(Play1.Report.summary_section(result.initial, result.final))
        if result.path, do: Mix.shell().info("Script written to #{Path.expand(result.path)}")

      {:error, reason, partial} ->
        if partial.path,
          do: Mix.shell().error("Partial script written to #{Path.expand(partial.path)}")

        Mix.raise(
          "Performance failed after #{Enum.count(partial.entries, &match?({:beat, _}, &1))} beats: #{inspect(reason)}"
        )
    end
  end
end
