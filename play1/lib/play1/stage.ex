defmodule Play1.Stage do
  @moduledoc """
  Performs *An Evening at Mrs. Ashworth's* under a director.

  For each scene the stage asks the director agent for a plan (who, what,
  where), puts those characters in that room, and lets them take beats in
  turn, delivering each beat only to those in the room. After every beat past
  a minimum it asks the director whether the scene has reached its moment;
  when it has, the director's closing line ends the scene. Arrivals the
  director planned join after the beat they were set for; a character may
  still withdraw or leave with any beat. The one disruption, the Reverend
  Ambrose brought down to think, happens when the director calls for it.

  The stage reads no private state until the play is over.
  """

  alias Jido.Signal
  alias Play1.{Beat, Cast, Character, Director, Plan, Report, Room}

  @min_beats 4

  @type entry ::
          {:scene, Plan.t()}
          | {:beat, Beat.t()}
          | {:note, String.t()}
          | {:closing, pos_integer(), String.t()}

  @type result :: %{
          path: Path.t() | nil,
          entries: [entry()],
          initial: %{Cast.id() => map()},
          final: %{Cast.id() => map()},
          director: map(),
          script: String.t()
        }

  @doc """
  Options: `:scenes` (default 5), `:out`, `:quiet`, `:timeout`.
  On failure returns `{:error, reason, partial_result}`.
  """
  @spec run(keyword()) :: {:ok, result()} | {:error, term(), result()}
  def run(opts \\ []) do
    scenes = max(Keyword.get(opts, :scenes, 5), 1)
    out = Keyword.get(opts, :out, default_path())

    initial = Map.new(Cast.ids(), &{&1, Cast.initial_state(&1)})
    :ok = start_agents(initial)

    stage = %{
      room: Enum.reduce(Cast.company(), Room.new(), &Room.enter(&2, &1, "the drawing-room")),
      seq: 1,
      scenes: scenes,
      timeout: Keyword.get(opts, :timeout, 240_000),
      quiet: Keyword.get(opts, :quiet, false),
      entries: [],
      last_spoke: %{},
      last_addressed: nil
    }

    unless stage.quiet, do: IO.puts(Report.header())

    {status, stage} =
      case Enum.reduce_while(1..scenes, {:ok, stage}, &scene_step/2) do
        {:ok, stage} -> {:ok, note(stage, "FADE OUT.")}
        {:error, reason, stage} -> {{:error, reason}, stage}
      end

    final = Map.new(Cast.ids(), &{&1, read_state(&1)})
    director = read_state(:director)
    stop_agents()

    entries = Enum.reverse(stage.entries)
    script = Report.render(entries, initial, final, director)
    path = write(out, script)

    result = %{
      path: path,
      entries: entries,
      initial: initial,
      final: final,
      director: director,
      script: script
    }

    case status do
      :ok -> {:ok, result}
      {:error, reason} -> {:error, reason, result}
    end
  end

  defp scene_step(number, {:ok, stage}) do
    available = Room.present(stage.room)

    if length(available -- [Cast.visitor()]) < 2 do
      {:halt, {:ok, stage}}
    else
      case scene(stage, number) do
        {:ok, stage} -> {:cont, {:ok, stage}}
        error -> {:halt, error}
      end
    end
  end

  # --- one scene ----------------------------------------------------------------

  defp scene(stage, number) do
    with {:ok, plan} <- plan_scene(stage, number) do
      # Everyone cast goes to the scene's room; everyone else present goes elsewhere
      # in the house, out of earshot, until the director calls for them.
      elsewhere = Enum.find(Cast.rooms(), &(&1 != plan.where))

      room =
        Room.present(stage.room)
        |> Enum.reduce(stage.room, fn id, room ->
          Room.enter(room, id, if(id in plan.who, do: plan.where, else: elsewhere))
        end)

      stage =
        stage
        |> Map.put(:room, room)
        |> Map.put(:last_addressed, nil)
        |> Map.update!(:entries, &[{:scene, plan} | &1])
        |> maybe_print({:scene, plan})

      scene_state = %{
        plan: plan,
        beats: 0,
        transcript: [],
        arrivals: plan.arrivals,
        first: plan.opening_line_by
      }

      with {:ok, stage, scene_state} <- maybe_disrupt(stage, scene_state),
           {:ok, stage, _scene_state} <- beats(stage, scene_state) do
        {:ok, stage}
      end
    end
  end

  defp beats(stage, sc) do
    on = Room.members(stage.room, sc.plan.where) -- [Cast.visitor()]

    cond do
      length(on) < 2 or sc.beats >= sc.plan.max_beats ->
        finish(stage, sc, true)

      true ->
        {stage, sc} = maybe_arrive(stage, sc)
        speaker = sc.first || choose_speaker(stage, sc.plan.where)
        phase = if sc.plan.number == stage.scenes, do: :last, else: :scene

        case take(stage, speaker, phase, sc.plan.where, sc.plan.premise, cue(sc)) do
          {:ok, stage, beat} ->
            sc = %{
              sc
              | beats: sc.beats + 1,
                transcript: sc.transcript ++ [Beat.to_script(beat)],
                first: nil
            }

            if sc.beats >= @min_beats do
              case judge(stage, sc, false) do
                {:ok, %{decision: :end} = verdict} -> close(stage, sc, verdict)
                {:ok, _continue} -> beats(stage, sc)
                {:error, reason} -> {:error, reason, stage}
              end
            else
              beats(stage, sc)
            end

          {:error, reason, stage} ->
            {:error, reason, stage}
        end
    end
  end

  defp finish(stage, sc, forced) do
    case judge(stage, sc, forced) do
      {:ok, verdict} -> close(stage, sc, verdict)
      {:error, reason} -> {:error, reason, stage}
    end
  end

  defp close(stage, sc, verdict) do
    text = verdict.closing || "Nobody answers."

    stage =
      stage
      |> Map.update!(:entries, &[{:closing, sc.plan.number, text} | &1])
      |> maybe_print({:closing, sc.plan.number, text})

    {:ok, stage, sc}
  end

  defp cue(%{beats: 0, plan: plan}),
    do: "The scene opens. #{if plan.opening_line_by, do: "You have the first line.", else: ""}"

  defp cue(_), do: "Do what this person would do next in this scene."

  defp maybe_arrive(stage, %{arrivals: []} = sc), do: {stage, sc}

  defp maybe_arrive(stage, sc) do
    {due, later} = Enum.split_with(sc.arrivals, &(&1.after_beats <= sc.beats))

    stage =
      Enum.reduce(due, stage, fn %{who: who}, stage ->
        if Room.place_of(stage.room, who) do
          {room, _} = Room.move(stage.room, who, {:place_room, sc.plan.where})
          stage |> Map.put(:room, room) |> note("#{Cast.stage_name(who)} comes in.")
        else
          stage
        end
      end)

    first =
      case due do
        [%{who: who} | _] -> who
        [] -> sc.first
      end

    {stage, %{sc | arrivals: later, first: first}}
  end

  # The director asked for Ambrose: Mrs. Ashworth brings him down, he thinks,
  # everyone present reacts, she takes him out; then the scene goes on.
  defp maybe_disrupt(stage, %{plan: %{disruption: false}} = sc), do: {:ok, stage, sc}

  defp maybe_disrupt(stage, sc) do
    visitor = Cast.visitor()
    host = Cast.host()
    where = sc.plan.where

    room = stage.room |> Room.enter(host, where) |> Room.enter(visitor, where)

    stage =
      stage
      |> Map.put(:room, room)
      |> note(
        "MRS. ASHWORTH goes out. A pause. She returns leading the REVEREND AMBROSE ASHWORTH by the arm: seventy, a black coat too large for him, his hat held in both hands."
      )

    with {:ok, stage, b1} <-
           take(
             stage,
             host,
             :scene,
             where,
             sc.plan.premise,
             "You have brought your brother-in-law Ambrose down from the second floor. Introduce him to your friends in your own fashion, take his hat from him, and command him: think, Ambrose."
           ),
         {:ok, stage, b2} <-
           take(
             stage,
             visitor,
             :scene,
             where,
             sc.plan.premise,
             "Mrs. Ashworth has taken your hat and told you to think."
           ),
         {:ok, stage, reactions} <- reactions(stage, where, sc.plan.premise),
         {:ok, stage, b3} <-
           take(
             stage,
             host,
             :scene,
             where,
             sc.plan.premise,
             "That is enough. Give Ambrose his hat and take him out, saying what a hostess says to cover it."
           ) do
      {room, _} = Room.move(stage.room, visitor, :leave)

      stage =
        stage
        |> Map.put(:room, room)
        |> note("MRS. ASHWORTH leads AMBROSE out. The door closes. Nobody speaks for a moment.")

      lines = Enum.map([b1, b2] ++ reactions ++ [b3], &Beat.to_script/1)

      {:ok, stage,
       %{sc | beats: sc.beats + length(lines), transcript: sc.transcript ++ lines, first: nil}}
    end
  end

  defp reactions(stage, where, premise) do
    cue =
      "You have just heard the Reverend Ambrose think. You are profoundly affected: awed, disgusted, moved, frightened, or changed; decide which, and let it bend your game, your beliefs, or your feeling toward somebody present."

    present = Room.members(stage.room, where) -- [Cast.visitor(), Cast.host()]

    Enum.reduce_while(present, {:ok, stage, []}, fn id, {:ok, stage, acc} ->
      case take(stage, id, :scene, where, premise, cue) do
        {:ok, stage, beat} -> {:cont, {:ok, stage, acc ++ [beat]}}
        {:error, reason, stage} -> {:halt, {:error, reason, stage}}
      end
    end)
  end

  # --- the director -------------------------------------------------------------

  defp plan_scene(stage, number) do
    signal =
      Signal.new!(
        "scene.plan",
        %{number: number, total: stage.scenes, available: Room.present(stage.room)},
        source: "/stage"
      )

    :ok = Jido.AgentServer.cast(pid!(:director), signal)

    receive do
      {:signal, %Signal{type: "scene.planned", data: %{plan: plan}}} ->
        {:ok, plan}

      {:signal, %Signal{type: "scene.failed", data: data}} ->
        {:error, {:plan_failed, number, data}, stage}
    after
      stage.timeout -> {:error, {:timeout, :plan, number}, stage}
    end
  end

  defp judge(stage, sc, forced) do
    signal =
      Signal.new!(
        "scene.judge",
        %{
          plan: sc.plan,
          transcript: sc.transcript,
          beats: sc.beats,
          min_beats: @min_beats,
          forced: forced
        },
        source: "/stage"
      )

    :ok = Jido.AgentServer.cast(pid!(:director), signal)

    receive do
      {:signal, %Signal{type: "scene.judged", data: %{verdict: verdict}}} ->
        {:ok, verdict}

      {:signal, %Signal{type: "scene.failed", data: data}} ->
        {:error, {:judge_failed, sc.plan.number, data}}
    after
      stage.timeout -> {:error, {:timeout, :judge, sc.plan.number}}
    end
  end

  # --- speakers and beats ---------------------------------------------------------

  defp choose_speaker(stage, where) do
    members = Room.members(stage.room, where) -- [Cast.visitor()]
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
      {:scene, _} -> nil
      _ -> false
    end)
    |> case do
      false -> nil
      other -> other
    end
  end

  defp cast_index(id), do: Enum.find_index(Cast.ids(), &(&1 == id))

  defp take(stage, speaker, phase, where, premise, cue) do
    group = Room.members(stage.room, where)
    elsewhere = Room.present(stage.room) -- (group -- [Cast.visitor()])

    signal =
      Signal.new!(
        "beat.take",
        %{
          seq: stage.seq,
          phase: phase,
          place: where,
          group: group,
          elsewhere: elsewhere,
          premise: premise,
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

        {:ok, stage, beat}

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
      :withdraw -> note(stage, "#{Cast.stage_name(speaker)} goes out, toward #{to}.")
      _ -> stage
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

  # --- housekeeping ---------------------------------------------------------------

  defp note(stage, text),
    do: stage |> Map.update!(:entries, &[{:note, text} | &1]) |> maybe_print({:note, text})

  defp maybe_print(%{quiet: true} = stage, _entry), do: stage

  defp maybe_print(stage, entry) do
    IO.puts(Report.entry_text(entry))
    stage
  end

  defp start_agents(initial) do
    {:ok, _} =
      Play1.Jido.start_agent(Director, id: "director", initial_state: %{observer: self()})

    Enum.each(initial, fn {id, state} ->
      {:ok, _} =
        Play1.Jido.start_agent(Character,
          id: Cast.agent_id(id),
          initial_state: Map.put(state, :observer, self())
        )
    end)
  end

  defp stop_agents do
    Enum.each(["director" | Enum.map(Cast.ids(), &Cast.agent_id/1)], fn agent_id ->
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

  defp read_state(:director) do
    {:ok, %{agent: agent}} = Jido.AgentServer.state(pid!(:director))
    agent.state
  end

  defp read_state(id) do
    {:ok, %{agent: agent}} = Jido.AgentServer.state(pid!(id))
    agent.state
  end

  defp pid!(:director), do: Play1.Jido.whereis("director") || raise("no running director")
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
