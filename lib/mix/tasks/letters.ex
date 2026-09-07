defmodule Mix.Tasks.Letters do
  @shortdoc "Run The Etheridge Circle, 1891"

  @moduledoc """
  Runs one story, prints the letters as they arrive, then the debug and
  summary sections, and writes the whole report under `letters/`.

      mix letters                    # ten letters: scripted opening, then free choice
      mix letters --letters 12
      mix letters --no-opening       # characters choose recipients from the start
      mix letters --stub             # deterministic canned model, no network
      mix letters --out story.txt
  """

  use Mix.Task

  @impl true
  def run(args) do
    {opts, _rest, _invalid} =
      OptionParser.parse(args,
        strict: [
          letters: :integer,
          opening: :boolean,
          stub: :boolean,
          out: :string,
          timeout: :integer
        ]
      )

    if opts[:stub], do: Application.put_env(:jido_demo1, :llm_client, JidoDemo1.LLM.Stub)

    Mix.Task.run("app.start")

    story_opts = Keyword.take(opts, [:letters, :opening, :out, :timeout])

    case JidoDemo1.Story.run(story_opts) do
      {:ok, result} ->
        Mix.shell().info(JidoDemo1.Report.debug_section(result.entries))
        Mix.shell().info(JidoDemo1.Report.summary_section(result.initial, result.final))
        if result.path, do: Mix.shell().info("Report written to #{Path.expand(result.path)}")

      {:error, reason} ->
        Mix.raise("Story failed: #{inspect(reason)}")
    end
  end
end
