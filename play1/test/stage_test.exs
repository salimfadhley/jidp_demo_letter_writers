defmodule Play1.StageTest do
  use ExUnit.Case, async: false

  alias Play1.{Beat, Cast, Plan, Stage}

  @opts [out: nil, quiet: true, timeout: 10_000]

  test "the director sets up each scene, the actors play it, and the director ends it" do
    {:ok, result} = Stage.run(Keyword.put(@opts, :scenes, 4))

    plans = for {:scene, p} <- result.entries, do: p
    closings = for {:closing, n, _} <- result.entries, do: n
    beats = for {:beat, b} <- result.entries, do: b

    assert length(plans) == 4
    assert closings == [1, 2, 3, 4]
    assert Enum.all?(plans, &match?(%Plan{}, &1))

    # Scene 1 opens on two people; the stub's planned arrival comes in after beat 3.
    [first | _] = plans
    assert first.who == [:helena_marchmont, :arthur_pembroke]
    scene1 = Enum.filter(beats, &(&1.seq <= 8))
    assert Enum.all?(Enum.take(scene1, 3), &(&1.group == [:helena_marchmont, :arthur_pembroke]))
    assert Enum.any?(result.entries, &match?({:note, "Enter MISS VANE."}, &1))

    # The disruption happens in the scene the director asked for it, once, with the keeper,
    # and everyone present is affected in a different way.
    assert [%Beat{speaker: :ambrose_ashworth, seq: mono}] =
             Enum.filter(beats, &(&1.kind == :monologue))

    assert Enum.count(plans, & &1.disruption) == 1
    # The keeper leaves once, with Ambrose, however his beats are worded.
    assert Enum.count(result.entries, &match?({:note, "Exit CRUTTWELL" <> _}, &1)) == 0
    assert Enum.count(result.entries, &match?({:note, "Exeunt CRUTTWELL" <> _}, &1)) == 1
    keeper_beats = Enum.filter(beats, &(&1.speaker == :barnabas_cruttwell))
    assert length(keeper_beats) == 2
    assert Enum.all?(keeper_beats, &(&1.place == "the drawing-room"))
    disruption_plan = Enum.find(plans, & &1.disruption)
    present = Enum.at(beats, mono - 1).group -- Cast.visitors()
    assigned = Play1.Plan.assign_reactions(disruption_plan, present)
    assert map_size(assigned) == length(present)
    assert assigned |> Map.values() |> Enum.uniq() |> length() == length(present)
    assert assigned.helena_marchmont == :awe
    assert assigned.arthur_pembroke != :awe
    assert assigned.julian_strake == :anger

    # The director's own record grows a line per scene, and it saw no private state.
    assert length(result.director.synopsis) == 4
    assert result.script =~ "[Director's note:"
    assert result.script =~ "SCENE THREE"
    assert result.script =~ "THE DIRECTOR'S BOOK"
    assert result.script =~ "CURTAIN."
  end

  test "the spotlight names one character at a time, who then speaks every other beat" do
    {:ok, result} = Stage.run(Keyword.put(@opts, :scenes, 1))
    spots = for {:spotlight, who} <- result.entries, do: who
    assert hd(spots) == :helena_marchmont
    assert length(Enum.uniq(spots)) >= 2
    assert result.script =~ "[Spotlight: MRS. MARCHMONT]"

    # Walk the entries: after each spotlight line, the lit character speaks on alternate beats.
    {_, ok?} =
      Enum.reduce(result.entries, {nil, true}, fn
        {:spotlight, who}, {_, ok} ->
          {{who, nil}, ok}

        {:beat, b}, {{who, last}, ok} ->
          expected = if last != who and who in b.group, do: who, else: nil
          {{who, b.speaker}, ok and (is_nil(expected) or b.speaker == expected)}

        _, acc ->
          acc
      end)

    assert ok?
  end

  test "a scene cannot end before somebody's thing has been shown" do
    # The stub says the thing is shown from beat 3 and asks to end from beat 6, so
    # a verdict at beat 4 with nothing revealed must be forced to continue.
    plan = %Play1.Plan{
      number: 1,
      who: [:helena_marchmont, :arthur_pembroke],
      where: "the parlour",
      premise: "p",
      note: "n"
    }

    base = %{
      plan: plan,
      transcript: [],
      beats: 6,
      min_beats: 4,
      spotlight: :helena_marchmont,
      lit: [],
      present: plan.who,
      forced: false
    }

    unrevealed =
      Play1.Actions.JudgeScene.parse(
        %{"decision" => "end", "thing_shown" => false},
        Map.put(base, :revealed, [])
      )

    assert unrevealed.decision == :continue

    revealed =
      Play1.Actions.JudgeScene.parse(
        %{"decision" => "end", "thing_shown" => false},
        Map.put(base, :revealed, [:arthur_pembroke])
      )

    assert revealed.decision == :end

    shown_now =
      Play1.Actions.JudgeScene.parse(
        %{"decision" => "end", "thing_shown" => true},
        Map.put(base, :revealed, [])
      )

    assert shown_now.decision == :end
  end

  test "characters witness only the beats spoken in the room they were in" do
    {:ok, result} = Stage.run(Keyword.put(@opts, :scenes, 3))
    beats = for {:beat, b} <- result.entries, do: b

    for id <- Cast.company() do
      heard = result.final[id].witnessed |> Enum.map(& &1.seq) |> MapSet.new()

      should =
        beats
        |> Enum.filter(&(id in &1.group))
        |> Enum.map(& &1.seq)
        |> Enum.take(-40)
        |> MapSet.new()

      assert heard == should, "#{id} heard the wrong beats"
    end
  end

  test "the script reads as a stage play" do
    {:ok, result} = Stage.run(Keyword.put(@opts, :scenes, 2))

    assert result.script =~
             "\nMRS. MARCHMONT. (sips the cup) Mrs. Marchmont says a thing at beat 1."

    assert result.script =~
             "SCENE ONE\n\nThe drawing-room. Continuous. Lights up on MRS. MARCHMONT, DR. PEMBROKE."

    assert result.script =~ "        (Enter MISS VANE.)"
    assert result.script =~ "        (Lights down.)"
    refute result.script =~ "INT."
  end

  test "two stub performances are identical" do
    {:ok, a} = Stage.run(Keyword.put(@opts, :scenes, 2))
    {:ok, b} = Stage.run(Keyword.put(@opts, :scenes, 2))
    assert a.script == b.script
  end
end
