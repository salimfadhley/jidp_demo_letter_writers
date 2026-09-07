defmodule JidoDemo1.Story do
  @moduledoc """
  Orchestrates one run of the correspondence.

  Starts one `JidoDemo1.Correspondent` agent per character, sends the opening
  premise to the first, and then waits, as the observer, for every letter to be
  written. Returns the path of the finished text file.
  """

  require Logger

  alias Jido.Signal
  alias JidoDemo1.{Characters, Correspondent, LetterFile}

  @default_letters 8
  @default_premise "A parcel has arrived at your house that was clearly intended for " <>
                     "somebody else, and its contents are both alarming and hard to explain."

  @spec run(keyword()) :: {:ok, Path.t()} | {:error, term()}
  def run(opts \\ []) do
    letters = Keyword.get(opts, :letters, @default_letters)
    premise = Keyword.get(opts, :premise, @default_premise)
    per_letter_timeout = Keyword.get(opts, :timeout, 180_000)

    characters = Characters.all()
    path = LetterFile.new_path()
    :ok = start_agents(characters, path, letters)

    first = hd(characters)
    Logger.info("Story begins: #{first.name} opens the correspondence")

    signal = Signal.new!("letter.received", %{body: premise, number: 0}, source: "/story")
    :ok = Jido.AgentServer.cast(JidoDemo1.Jido.whereis(first.id), signal)

    result = collect(letters, per_letter_timeout)
    stop_agents(characters)

    case result do
      :ok -> {:ok, path}
      {:error, _} = error -> error
    end
  end

  defp start_agents(characters, path, letters) do
    count = length(characters)

    characters
    |> Enum.with_index()
    |> Enum.each(fn {character, index} ->
      next = Enum.at(characters, rem(index + 1, count))

      acquaintances =
        characters
        |> Enum.reject(&(&1.id == character.id))
        |> Enum.map_join("\n", &"- #{&1.name}, #{&1.persona}")

      {:ok, _pid} =
        JidoDemo1.Jido.start_agent(Correspondent,
          id: character.id,
          initial_state: %{
            name: character.name,
            persona: character.persona,
            acquaintances: acquaintances,
            next_id: next.id,
            next_name: next.name,
            observer: self(),
            letter_path: path,
            max_letters: letters
          }
        )
    end)
  end

  defp stop_agents(characters) do
    Enum.each(characters, fn character ->
      case JidoDemo1.Jido.whereis(character.id) do
        nil -> :ok
        _pid -> JidoDemo1.Jido.stop_agent(character.id)
      end
    end)
  end

  defp collect(0, _timeout), do: :ok

  defp collect(remaining, timeout) do
    receive do
      {:signal, %Signal{type: "letter.received", data: %{number: n, from: from}}} ->
        Logger.info("Letter #{n} written by #{from} (#{remaining - 1} to go)")
        collect(remaining - 1, timeout)

      {:signal, %Signal{type: "letter.failed", data: data}} ->
        {:error, {:letter_failed, data}}
    after
      timeout -> {:error, {:timeout, remaining_letters: remaining}}
    end
  end
end
