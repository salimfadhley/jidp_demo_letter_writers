defmodule JidoDemo1.Story do
  @moduledoc """
  Directs one run of *The Etheridge Circle, 1891*.

  The director is a clock and a postmaster, not a narrator. It starts one agent
  per character and seeds the first letter. After that the characters drive the
  story: when a character receives a letter it decides, privately, whether to
  ignore it, reply, write to somebody else about it, or write about something
  else, and the director queues that decision and follows it. Because the
  post does not wait, the director also invites any character who has neither
  written nor received a letter for a while to write unprompted, leaving the
  choice of recipient and subject to them; that is also how the story
  continues when a letter is left unanswered.

  The director never writes prose and never reads an agent's private state
  while the story runs. It reads final state once, for the summary.
  """

  alias Jido.Signal
  alias JidoDemo1.{Appraisal, Cast, Character, Letter, Report}

  @start_date ~D[1891-10-14]
  @days_between_letters 2
  @letters_per_round 4

  # A character who has neither written nor received for this many letters is
  # invited to write unprompted, ahead of whatever decisions are queued.
  @idle_after 4

  @seed {:helena_marchmont, :arthur_pembroke,
         "To tell him she went to Mrs. Ashworth's sitting after all, and to ask whether he can " <>
           "explain what happened there without cruelty, because she can no longer tell whether " <>
           "what she felt was faith or its collapse."}

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

  @typedoc "One letter and the recipient's reaction to it."
  @type entry :: %{letter: Letter.t(), appraisal: Appraisal.t() | nil, origin: String.t()}

  @type result :: %{
          path: Path.t() | nil,
          entries: [entry()],
          initial: %{Cast.id() => map()},
          final: %{Cast.id() => map()},
          report: String.t()
        }

  # What the director asks of a character: who writes, to whom (nil = their
  # choice), for what purpose, and a note on why this letter is happening.
  @typep instruction :: %{
           from: Cast.id(),
           to: Cast.id() | nil,
           purpose: String.t() | nil,
           in_reply_to: String.t() | nil,
           origin: String.t()
         }

  @doc "The scripted opening sequence of `{from, to}` pairs, used with `opening: true`."
  @spec opening() :: [{Cast.id(), Cast.id()}]
  def opening, do: @opening

  @doc """
  Run a story.

  Options:

  - `:letters` total letters to write (default 10).
  - `:opening` set true to force the scripted eight-letter opening before the
    characters take over. Off by default: only the first letter is seeded.
  - `:out` path for the report; `nil` writes nothing to disk.
  - `:quiet` suppress printing letters as they arrive.
  - `:timeout` milliseconds to wait for each step (default 300 000).

  On failure the letters written so far are still rendered to `:out`, and the
  error is `{:error, reason, partial_result}`.
  """
  @spec run(keyword()) :: {:ok, result()} | {:error, term(), result()}
  def run(opts \\ []) do
    total = Keyword.get(opts, :letters, 10)
    timeout = Keyword.get(opts, :timeout, 300_000)
    quiet = Keyword.get(opts, :quiet, false)
    out = Keyword.get(opts, :out, default_path())
    scripted = if Keyword.get(opts, :opening, false), do: @opening, else: []

    initial = Map.new(Cast.ids(), &{&1, Cast.initial_state(&1)})
    :ok = start_agents(initial)

    unless quiet, do: IO.puts(Report.header())

    loop = %{
      queue: if(scripted == [], do: [seed()], else: []),
      scripted: scripted,
      seq: 1,
      total: total,
      timeout: timeout,
      quiet: quiet,
      last_active: Map.new(Cast.ids(), &{&1, 0}),
      entries: []
    }

    {status, reversed} = correspond(loop)

    final = Map.new(Cast.ids(), &{&1, read_state(&1)})
    stop_agents()

    entries = Enum.reverse(reversed)
    report = Report.render(entries, initial, final)
    path = write_report(out, report)
    result = %{path: path, entries: entries, initial: initial, final: final, report: report}

    case status do
      :ok -> {:ok, result}
      {:error, reason} -> {:error, reason, result}
    end
  end

  # The main loop. Each turn asks one character to write, waits for the letter
  # and for the recipient's appraisal (which carries their decision), queues
  # whatever that decision calls for, and goes round again.
  defp correspond(%{seq: seq, total: total, entries: entries}) when seq > total,
    do: {:ok, entries}

  defp correspond(loop) do
    {instruction, loop} = next_instruction(loop)

    case step(instruction, loop.seq, loop.timeout) do
      {:ok, entry} ->
        unless loop.quiet, do: IO.puts(Report.letter_text(entry.letter))

        loop
        |> Map.update!(:entries, &[entry | &1])
        |> Map.update!(:last_active, &touch(&1, entry.letter, loop.seq))
        |> Map.update!(:queue, &enqueue(&1, follow(entry)))
        |> Map.update!(:seq, &(&1 + 1))
        |> correspond()

      {:error, reason} ->
        {{:error, reason}, loop.entries}
    end
  end

  # Who writes now: the script while it lasts, otherwise an idle character,
  # otherwise the oldest queued decision, otherwise whoever has been quiet longest.
  defp next_instruction(%{scripted: [{from, to} | rest]} = loop) do
    {%{from: from, to: to, purpose: nil, in_reply_to: nil, origin: "scripted opening"},
     %{loop | scripted: rest}}
  end

  defp next_instruction(loop) do
    case {idle_character(loop), loop.queue} do
      {nil, [instruction | rest]} -> {instruction, %{loop | queue: rest}}
      {nil, []} -> {invite(quietest(loop), loop), loop}
      {id, _} -> {invite(id, loop), loop}
    end
  end

  # A character's newest decision replaces any older one still waiting.
  defp enqueue(queue, []), do: queue

  defp enqueue(queue, [instruction]) do
    Enum.reject(queue, &(&1.from == instruction.from)) ++ [instruction]
  end

  defp idle_character(loop) do
    loop.last_active
    |> Enum.filter(fn {_id, last} -> loop.seq - last > @idle_after end)
    |> Enum.reject(fn {id, _} -> Enum.any?(loop.queue, &(&1.from == id)) end)
    |> Enum.min_by(fn {id, last} -> {last, cast_index(id)} end, fn -> nil end)
    |> case do
      nil -> nil
      {id, _} -> id
    end
  end

  defp quietest(loop) do
    loop.last_active
    |> Enum.min_by(fn {id, last} -> {last, cast_index(id)} end)
    |> elem(0)
  end

  defp invite(id, loop) do
    since =
      case loop.last_active[id] do
        0 -> "had not yet written or received a letter"
        n -> "had neither written nor received a letter since letter-#{pad(n)}"
      end

    %{
      from: id,
      to: nil,
      purpose: nil,
      in_reply_to: nil,
      origin: "unprompted; #{Cast.short_name(id)} #{since} and was invited to write"
    }
  end

  defp touch(last_active, letter, seq) do
    last_active |> Map.put(letter.from, seq) |> Map.put(letter.to, seq)
  end

  defp cast_index(id), do: Enum.find_index(Cast.ids(), &(&1 == id))

  defp pad(n), do: String.pad_leading(Integer.to_string(n), 3, "0")

  defp seed do
    {from, to, purpose} = @seed

    %{
      from: from,
      to: to,
      purpose: purpose,
      in_reply_to: nil,
      origin: "Mrs. Ashworth's invitation and the séance"
    }
  end

  # What a finished entry asks of the director next: nothing if the recipient
  # ignores it, otherwise the letter they resolved to write.
  @spec follow(entry()) :: [instruction()]
  defp follow(%{letter: letter, appraisal: %{decision: %{action: :write} = decision}}) do
    [
      %{
        from: letter.to,
        to: decision.to,
        purpose: decision.purpose,
        in_reply_to: letter.id,
        origin: "#{Cast.short_name(letter.to)}'s decision on reading #{letter.id}"
      }
    ]
  end

  defp follow(_entry), do: []

  defp step(instruction, seq, timeout) do
    round = div(seq - 1, @letters_per_round) + 1
    date = Date.add(@start_date, (seq - 1) * @days_between_letters)

    signal =
      Signal.new!(
        "letter.compose",
        %{
          to: instruction.to,
          purpose: instruction.purpose,
          in_reply_to: instruction.in_reply_to,
          seq: seq,
          round: round,
          date: Date.to_iso8601(date)
        },
        source: "/director"
      )

    :ok = Jido.AgentServer.cast(pid!(instruction.from), signal)

    with {:ok, letter} <- await_sent(seq, timeout),
         {:ok, appraisal} <- await_appraised(letter, timeout) do
      {:ok, %{letter: letter, appraisal: appraisal, origin: instruction.origin}}
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
