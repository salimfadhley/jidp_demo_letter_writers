defmodule Mix.Tasks.Letters do
  @shortdoc "Run the four-correspondent letter-writing demo"

  @moduledoc """
  Runs one story and prints the path of the resulting text file.

      mix letters
      mix letters --letters 12
      mix letters --premise "The vicar has announced a bicycle race."
  """

  use Mix.Task

  @impl true
  def run(args) do
    {opts, _rest, _invalid} =
      OptionParser.parse(args, strict: [letters: :integer, premise: :string, timeout: :integer])

    Mix.Task.run("app.start")

    case JidoDemo1.Story.run(opts) do
      {:ok, path} ->
        Mix.shell().info("\nStory complete. Read it at: #{Path.expand(path)}")

      {:error, reason} ->
        Mix.raise("Story failed: #{inspect(reason)}")
    end
  end
end
