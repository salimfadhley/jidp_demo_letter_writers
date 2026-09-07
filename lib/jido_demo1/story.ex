defmodule JidoDemo1.Story do
  @moduledoc """
  Directs one run of *The Etheridge Circle, 1891*.

  The director is not a narrator: it never writes prose or reads private state
  while the story runs. It starts one agent per character, tells a character
  when to write (and, for the scripted opening, to whom), and waits for the
  agents' own notifications that a letter was sent and appraised. Only after
  the last letter does it read each agent's state to report how things moved.
  """

  alias Jido.Signal
  alias JidoDemo1.{Appraisal, Cast, Character, Letter, Report}

  @start_date ~D[1891-10-14]
  @days_between_letters 2
  @letters_per_round 4

  @opening [
    {:helena_marchmont, :arthur_pembroke},
    {:arthur_pembroke, :helena_marchmont},
    {:clara_vane, :helena_marchmont},
    {:julian_strake, :clara_vane},
    {:arthur_pembroke, :julian_strake},
    {:julian_strake, :helena_marchmont},
    {:clara_vane, :arthur_pembroke},
    {:helena_marchmont, :arthur_pembroke}
  ]

  @type entry :: %{letter: Letter.t(), appraisal: Appraisal.t() | nil}

  @type result :: %{
          path: Path.t() | nil,
          entries: [entry()],
          initial: %{Cast.id() => map()},
          final: %{Cast.id() => map()},
          report: String.t()
        }

  @doc """
  The scripted opening sequence of `{from, to}` pairs.
  """
  @spec opening() :: [{Cast.id(), Cast.id()}]
  def opening, do: @opening

  @doc """
  Run a story.

  Options:

  - `:letters` total letters to write (default 10). The first eight follow the
    scripted opening; after that each character in turn chooses its own recipient.
  - `:opening` set false to let characters choose from the first letter.
  - `:out` path for the report; `nil` writes nothing to disk.
  - `:quiet` suppress printing letters as they arrive.
  - `:timeout` milliseconds to wait for each step (default 180 000).
  """
  @spec run(keyword()) :: {:ok, result()} | {:error, term()}
  def run(opts \\ []) do
    total = Keyword.get(opts, :letters, 10)
    timeout = Keyword.get(opts, :timeout, 180_000)
    quiet = Keyword.get(opts, :quiet, false)
    out = Keyword.get(opts, :out, default_path())

    initial = Map.new(Cast.ids(), &{&1, Cast.initial_state(&1)})
    :ok = start_agents(initial)

    unless quiet, do: IO.puts(Report.header())

    steps = schedule(total, Keyword.get(opts, :opening, true))

    outcome =
      Enum.reduce_while(steps, {:ok, []}, fn {seq, from, to}, {:ok, acc} ->
        case step(seq, from, to, timeout) do
          {:ok, entry} ->
            unless quiet, do: IO.puts(Report.letter_text(entry.letter))
            {:cont, {:ok, [entry | acc]}}

          {:error, reason} ->
            {:halt, {:error, reason}}
        end
      end)

    final = Map.new(Cast.ids(), &{&1, read_state(&1)})
    stop_agents()

    with {:ok, reversed} <- outcome do
      entries = Enum.reverse(reversed)
      report = Report.render(entries, initial, final)
      path = write_report(out, report)
      {:ok, %{path: path, entries: entries, initial: initial, final: final, report: report}}
    end
  end

  defp schedule(total, true) do
    scripted =
      @opening
      |> Enum.take(total)
      |> Enum.with_index(1)
      |> Enum.map(fn {{from, to}, seq} -> {seq, from, to} end)

    scripted ++ free_steps(length(scripted) + 1, total)
  end

  defp schedule(total, false), do: free_steps(1, total)

  defp free_steps(first_seq, total) when first_seq > total, do: []

  defp free_steps(first_seq, total) do
    Cast.ids()
    |> Stream.cycle()
    |> Enum.take(total - first_seq + 1)
    |> Enum.with_index(first_seq)
    |> Enum.map(fn {from, seq} -> {seq, from, nil} end)
  end

  defp step(seq, from, to, timeout) do
    round = div(seq - 1, @letters_per_round) + 1
    date = Date.add(@start_date, (seq - 1) * @days_between_letters)

    signal =
      Signal.new!(
        "letter.compose",
        %{to: to, seq: seq, round: round, date: Date.to_iso8601(date)},
        source: "/director"
      )

    :ok = Jido.AgentServer.cast(pid!(from), signal)

    with {:ok, letter} <- await_sent(seq, timeout),
         {:ok, appraisal} <- await_appraised(letter, timeout) do
      {:ok, %{letter: letter, appraisal: appraisal}}
    end
  end

  defp await_sent(seq, timeout) do
    receive do
      {:signal, %Signal{type: "letter.sent", data: %{letter: letter}}} ->
        {:ok, Letter.to_struct(letter)}

      {:signal, %Signal{type: "letter.failed", data: data}} ->
        {:error, {:compose_failed, seq, data}}
    after
      timeout -> {:error, {:timeout, :compose, seq}}
    end
  end

  defp await_appraised(letter, timeout) do
    receive do
      {:signal, %Signal{type: "letter.appraised", data: %{appraisal: appraisal}}} ->
        {:ok, appraisal}

      {:signal, %Signal{type: "letter.failed", data: data}} ->
        {:error, {:appraise_failed, letter.id, data}}
    after
      timeout -> {:error, {:timeout, :appraise, letter.id}}
    end
  end

  defp start_agents(initial) do
    Enum.each(initial, fn {id, state} ->
      {:ok, _pid} =
        JidoDemo1.Jido.start_agent(Character,
          id: Cast.agent_id(id),
          initial_state: Map.put(state, :observer, self())
        )
    end)
  end

  defp stop_agents do
    Enum.each(Cast.ids(), fn id ->
      agent_id = Cast.agent_id(id)

      case JidoDemo1.Jido.whereis(agent_id) do
        nil -> :ok
        _pid -> JidoDemo1.Jido.stop_agent(agent_id)
      end

      wait_until_gone(agent_id, 50)
    end)
  end

  defp wait_until_gone(_agent_id, 0), do: :ok

  defp wait_until_gone(agent_id, attempts) do
    case JidoDemo1.Jido.whereis(agent_id) do
      nil ->
        :ok

      _pid ->
        Process.sleep(10)
        wait_until_gone(agent_id, attempts - 1)
    end
  end

  defp read_state(id) do
    {:ok, %{agent: agent}} = Jido.AgentServer.state(pid!(id))
    agent.state
  end

  defp pid!(id) do
    case JidoDemo1.Jido.whereis(Cast.agent_id(id)) do
      nil -> raise "no running agent for #{id}"
      pid -> pid
    end
  end

  defp default_path do
    stamp = Calendar.strftime(DateTime.utc_now(), "%Y%m%d-%H%M%S")
    Path.join("letters", "etheridge-#{stamp}.txt")
  end

  defp write_report(nil, _report), do: nil

  defp write_report(path, report) do
    path |> Path.dirname() |> File.mkdir_p!()
    File.write!(path, report)
    path
  end
end
