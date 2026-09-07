defmodule Mix.Tasks.Letters do
  @shortdoc "Run The Etheridge Circle, 1891"

  @moduledoc """
  Runs one story, prints the letters as they arrive, then the debug and
  summary sections, and writes the whole report under `letters/`.

      mix letters                    # ten letters; after the first, the characters decide
      mix letters --letters 12
      mix letters --opening          # force the scripted eight-letter opening first
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

      {:error, reason, partial} ->
        if partial.path,
          do: Mix.shell().error("Partial report written to #{Path.expand(partial.path)}")

        Mix.raise("Story failed after #{length(partial.entries)} letters: #{inspect(reason)}")
    end
  end
end
