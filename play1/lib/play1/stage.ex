defmodule Play1.Stage do
  @moduledoc """
  Directs one performance of *An Evening at Mrs. Ashworth's*.

  One room, one conversation on camera at a time. The curtain rises on two
  people already talking; others cross the room and join; in the middle the
  hostess brings her brother-in-law down to think for the company; late in
  the evening people slip away. The stage is a camera and a postmaster, not a
  playwright: it keeps the room (who stands where), decides who in the
  on-camera group takes the next beat, delivers each beat only to those
  standing there, applies the moves the characters choose, and reads no
  private state until the end.
  """

  alias Jido.Signal
  alias Play1.{Beat, Cast, Character, Report, Room}

  @opening_beats 5
  @late_beats 8
  @join_every 5

  @type entry :: {:beat, Beat.t()} | {:cut, String.t(), [Cast.id()]} | {:note, String.t()}

  @type result :: %{
          path: Path.t() | nil,
          entries: [entry()],
          initial: %{Cast.id() => map()},
          final: %{Cast.id() => map()},
          script: String.t()
        }

  @doc """
  Options: `:beats` total (default 40, minimum 24), `:out`, `:quiet`, `:timeout`.
  On failure returns `{:error, reason, partial_result}`.
  """
  @spec run(keyword()) :: {:ok, result()} | {:error, term(), result()}
  def run(opts \\ []) do
    total = max(Keyword.get(opts, :beats, 40), 24)
    out = Keyword.get(opts, :out, default_path())

    initial = Map.new(Cast.ids(), &{&1, Cast.initial_state(&1)})
    :ok = start_agents(initial)

    room =
      Room.new()
      |> Room.enter(:helena_marchmont, "the fire")
      |> Room.enter(:arthur_pembroke, "the fire")
      |> Room.enter(:clara_vane, "the sideboard")
      |> Room.enter(:julian_strake, "the window")
      |> Room.enter(:lavinia_ashworth, "the door to the hall")

    stage = %{
      room: room,
      seq: 1,
      total: total,
      interlude_at: @opening_beats + div(total - @opening_beats - @late_beats, 2),
      interlude_done: false,
      timeout: Keyword.get(opts, :timeout, 240_000),
      quiet: Keyword.get(opts, :quiet, false),
      entries: [],
      focus: nil,
      # The first join falls just after the opening beats.
      last_join: @opening_beats - @join_every + 1,
      last_spoke: %{},
      last_addressed: nil
    }

    unless stage.quiet, do: IO.puts(Report.header())

    stage =
      stage
      |> note(
        "MRS. MARCHMONT and DR. PEMBROKE stand by the fire, a little apart from the rest, each holding a glass of cup neither has touched. Across the room MISS VANE examines the sideboard, MR. STRAKE the dark garden, and MRS. ASHWORTH, in the doorway, the hall."
      )
      |> cut_to("the fire")

    {status, stage} =
      case loop(stage) do
        {:ok, stage} -> {:ok, close(stage)}
        {:error, reason, stage} -> {{:error, reason}, stage}
      end

    final = Map.new(Cast.ids(), &{&1, read_state(&1)})
    stop_agents()

    entries = Enum.reverse(stage.entries)
    script = Report.render(entries, initial, final)
    path = write(out, script)
    result = %{path: path, entries: entries, initial: initial, final: final, script: script}

    case status do
      :ok -> {:ok, result}
      {:error, reason} -> {:error, reason, result}
    end
  end

  # --- the evening ---------------------------------------------------------

  defp loop(%{seq: seq, total: total} = stage) when seq > total, do: {:ok, stage}

  defp loop(stage) do
    cond do
      Room.present(stage.room) -- [Cast.host()] == [] ->
        {:ok, stage}

      stage.seq >= stage.interlude_at and not stage.interlude_done ->
        with {:ok, stage} <- interlude(stage), do: loop(stage)

      true ->
        with {:ok, stage} <- turn(stage), do: loop(stage)
    end
  end

  # One ordinary turn: perhaps someone joins, otherwise someone in the
  # conversation takes a beat.
  defp turn(stage) do
    stage = ensure_focus(stage)
    phase = phase(stage)

    case joiner(stage) do
      nil ->
        speaker = choose_speaker(stage)
        take(stage, speaker, phase, cue(phase))

      who ->
        {room, place} =
          Room.move(stage.room, who, {:join, hd(Room.members(stage.room, stage.focus))})

        stage
        |> Map.put(:room, room)
        |> Map.put(:last_join, stage.seq)
        |> note("#{Cast.stage_name(who)} crosses the room and joins them at #{place}.")
        |> take(
          who,
          phase,
          "You have just crossed the room and joined this conversation. Your first words, or your first action, on joining."
        )
    end
  end

  defp phase(%{seq: seq}) when seq <= @opening_beats, do: :opening
  defp phase(%{seq: seq, total: total}) when seq > total - @late_beats, do: :late
  defp phase(_), do: :party

  defp cue(:opening),
    do:
      "The evening is young and the two of you have the fire to yourselves. Say what this person would say next."

  defp cue(:party),
    do:
      "Nothing in particular is required of you. Do what this person would do next in this company."

  defp cue(:late),
    do:
      "It is late. The candles are low. You may say your piece and stay, or slip away to another part of the room (withdraw), or take your leave of the house (leave), as this person would."

  # Somebody off camera joins when the conversation has run a while, or at
  # once when it has dwindled to one.
  defp joiner(stage) do
    on = Room.members(stage.room, stage.focus)
    off = Room.present(stage.room) -- (on -- [Cast.visitor()])
    due? = stage.seq - stage.last_join >= @join_every and stage.seq > 2
    dwindled? = length(on) < 2

    cond do
      off == [] -> nil
      phase(stage) == :late and not dwindled? -> nil
      due? or dwindled? -> Enum.min_by(off, &{Map.get(stage.last_spoke, &1, 0), cast_index(&1)})
      true -> nil
    end
  end

  defp interlude(stage) do
    visitor = Cast.visitor()
    host = Cast.host()

    room =
      Enum.reduce(Room.present(stage.room), stage.room, &Room.enter(&2, &1, "the fire"))
      |> Room.enter(visitor, "the fire")

    stage =
      stage
      |> Map.put(:room, room)
      |> Map.put(:interlude_done, true)
      |> note(
        "MRS. ASHWORTH goes out. A pause; the talk falters. The company drifts toward the fire. She returns leading the REVEREND AMBROSE ASHWORTH by the arm: seventy, a black coat too large for him, his hat held in both hands."
      )
      |> cut_to("the fire")

    with {:ok, stage} <-
           take(
             stage,
             host,
             :party,
             "You have brought your brother-in-law Ambrose down from the second floor. Introduce him to your friends in your own fashion, take his hat from him, and command him: think, Ambrose."
           ),
         {:ok, stage} <-
           take(stage, visitor, :party, "Mrs. Ashworth has taken your hat and told you to think."),
         {:ok, stage} <- reactions(stage),
         {:ok, stage} <-
           take(
             stage,
             host,
             :party,
             "That is enough. Give Ambrose his hat and take him out, saying what a hostess says to cover it."
           ) do
      {room, _} = Room.move(stage.room, visitor, :leave)

      {:ok,
       stage
       |> Map.put(:room, room)
       |> Map.put(:last_join, stage.seq)
       |> note("MRS. ASHWORTH leads AMBROSE out. The door closes. Nobody speaks for a moment.")}
    end
  end

  defp reactions(stage) do
    cue =
      "You have just heard the Reverend Ambrose think. You are profoundly affected: awed, disgusted, moved, frightened, or changed; decide which, and let it bend your game, your beliefs, or your feeling toward somebody present."

    Enum.reduce_while(Cast.guests(), {:ok, stage}, fn guest, {:ok, stage} ->
      case take(stage, guest, :party, cue) do
        {:ok, stage} -> {:cont, {:ok, stage}}
        error -> {:halt, error}
      end
    end)
  end

  defp close(stage) do
    left = Room.present(stage.room)

    text =
      case left -- [Cast.host()] do
        [] ->
          "The room is empty but for MRS. ASHWORTH, who stands a moment by the fire, then turns down the gas."

        rest ->
          "The candles gutter. #{Enum.map_join(rest, ", ", &Cast.stage_name/1)} #{if length(rest) == 1, do: "is", else: "are"} still there when MRS. ASHWORTH turns down the gas."
      end

    stage |> note(text) |> note("FADE OUT.")
  end

  # --- camera ---------------------------------------------------------------

  defp ensure_focus(stage) do
    on = Room.members(stage.room, stage.focus)

    if length(on) >= 2 do
      stage
    else
      case Enum.find(Room.groups(stage.room), fn {_p, m} -> length(m) >= 2 end) do
        {place, _} -> cut_to(stage, place)
        nil -> stage
      end
    end
  end

  defp cut_to(%{focus: place} = stage, place), do: stage

  defp cut_to(stage, place) do
    members = Room.members(stage.room, place)

    %{stage | focus: place, last_addressed: nil}
    |> Map.update!(:entries, &[{:cut, place, members} | &1])
    |> maybe_print({:cut, place, members})
  end

  defp choose_speaker(stage) do
    members = Room.members(stage.room, stage.focus)
    last = last_speaker(stage)

    if stage.last_addressed in members and stage.last_addressed != last do
      stage.last_addressed
    else
      members
      |> Enum.reject(&(&1 == last and length(members) > 1))
      |> Enum.min_by(&{Map.get(stage.last_spoke, &1, 0), cast_index(&1)})
    end
  end

  defp last_speaker(stage) do
    Enum.find_value(stage.entries, fn
      {:beat, %Beat{speaker: s}} -> s
      _ -> nil
    end)
  end

  defp cast_index(id), do: Enum.find_index(Cast.ids(), &(&1 == id))

  # --- one beat ---------------------------------------------------------------

  defp take(stage, speaker, phase, cue) do
    place = Room.place_of(stage.room, speaker)
    group = Room.members(stage.room, place)
    elsewhere = Room.present(stage.room) -- (group -- [Cast.visitor()])

    signal =
      Signal.new!(
        "beat.take",
        %{
          seq: stage.seq,
          phase: phase,
          place: place,
          group: group,
          elsewhere: elsewhere,
          cue: cue
        },
        source: "/stage"
      )

    :ok = Jido.AgentServer.cast(pid!(speaker), signal)

    case await_beat(stage.seq, stage.timeout) do
      {:ok, beat} ->
        :ok = deliver(beat, group)

        stage =
          stage
          |> Map.update!(:entries, &[{:beat, beat} | &1])
          |> maybe_print({:beat, beat})
          |> Map.update!(:last_spoke, &Map.put(&1, speaker, stage.seq))
          |> Map.put(:last_addressed, beat.addressed_to)
          |> Map.update!(:seq, &(&1 + 1))
          |> apply_move(beat)

        {:ok, stage}

      {:error, reason} ->
        {:error, reason, stage}
    end
  end

  defp apply_move(stage, %Beat{move: nil}), do: stage

  defp apply_move(stage, %Beat{move: move, speaker: speaker}) do
    {room, to} = Room.move(stage.room, speaker, move)
    stage = Map.put(stage, :room, room)

    case move do
      :leave -> note(stage, "#{Cast.stage_name(speaker)} takes leave and goes out.")
      :withdraw -> note(stage, "#{Cast.stage_name(speaker)} drifts away toward #{to}.")
      {:join, _} -> stage
    end
  end

  defp deliver(%Beat{} = beat, group) do
    public = Beat.public(beat)

    group
    |> Enum.reject(&(&1 == beat.speaker))
    |> Enum.each(fn id ->
      {:ok, _} =
        Jido.AgentServer.call(
          pid!(id),
          Signal.new!("beat.heard", %{beat: public}, source: "/stage")
        )
    end)
  end

  defp await_beat(seq, timeout) do
    receive do
      {:signal, %Signal{type: "beat.taken", data: %{beat: beat}}} -> {:ok, Beat.to_struct(beat)}
      {:signal, %Signal{type: "beat.failed", data: data}} -> {:error, {:beat_failed, seq, data}}
    after
      timeout -> {:error, {:timeout, seq}}
    end
  end

  # --- housekeeping -------------------------------------------------------------

  defp note(stage, text),
    do: stage |> Map.update!(:entries, &[{:note, text} | &1]) |> maybe_print({:note, text})

  defp maybe_print(%{quiet: true} = stage, _entry), do: stage

  defp maybe_print(stage, entry) do
    IO.puts(Report.entry_text(entry))
    stage
  end

  defp start_agents(initial) do
    Enum.each(initial, fn {id, state} ->
      {:ok, _} =
        Play1.Jido.start_agent(Character,
          id: Cast.agent_id(id),
          initial_state: Map.put(state, :observer, self())
        )
    end)
  end

  defp stop_agents do
    Enum.each(Cast.ids(), fn id ->
      agent_id = Cast.agent_id(id)
      if Play1.Jido.whereis(agent_id), do: Play1.Jido.stop_agent(agent_id)
      wait_until_gone(agent_id, 50)
    end)
  end

  defp wait_until_gone(_id, 0), do: :ok

  defp wait_until_gone(id, n) do
    if Play1.Jido.whereis(id) do
      Process.sleep(10)
      wait_until_gone(id, n - 1)
    else
      :ok
    end
  end

  defp read_state(id) do
    {:ok, %{agent: agent}} = Jido.AgentServer.state(pid!(id))
    agent.state
  end

  defp pid!(id), do: Play1.Jido.whereis(Cast.agent_id(id)) || raise("no running agent for #{id}")

  defp default_path,
    do:
      Path.join(
        "scripts",
        "ashworth-#{Calendar.strftime(DateTime.utc_now(), "%Y%m%d-%H%M%S")}.txt"
      )

  defp write(nil, _), do: nil

  defp write(path, script) do
    path |> Path.dirname() |> File.mkdir_p!()
    File.write!(path, script)
    path
  end
end
