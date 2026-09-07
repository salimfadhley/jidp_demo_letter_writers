defmodule Play1.StageTest do
  use ExUnit.Case, async: false

  alias Play1.{Beat, Cast, Stage}

  @opts [out: nil, quiet: true, timeout: 10_000]

  test "the curtain rises on two, others join, the visitor thinks once, and people slip away" do
    {:ok, result} = Stage.run(Keyword.put(@opts, :beats, 40))
    beats = for {:beat, b} <- result.entries, do: b

    assert hd(beats).group == [:helena_marchmont, :arthur_pembroke]
    assert Enum.all?(Enum.take(beats, 5), &(&1.speaker in [:helena_marchmont, :arthur_pembroke]))

    speakers = beats |> Enum.map(& &1.speaker) |> Enum.uniq() |> Enum.sort()
    assert speakers == Enum.sort(Cast.ids())

    assert [%Beat{speaker: :ambrose_ashworth, group: group}] =
             Enum.filter(beats, &(&1.kind == :monologue))

    assert Enum.sort(group) == Enum.sort(Cast.ids())

    joins =
      Enum.filter(
        result.entries,
        &(match?({:note, "MRS." <> _}, &1) or match?({:note, "MISS" <> _}, &1) or
            match?({:note, "MR." <> _}, &1) or match?({:note, "DR." <> _}, &1))
      )

    assert Enum.any?(joins, fn {:note, t} -> t =~ "joins them" end)

    assert Enum.count(beats, &(&1.move == :leave)) >= 2
    assert result.script =~ "FADE IN:"
    assert result.script =~ "INT. MRS. ASHWORTH'S DRAWING-ROOM"
    assert result.script =~ "FADE OUT."
    assert result.script =~ "DEBUG: PRIVATE STATE PER BEAT"
  end

  test "characters witness only the beats spoken where they stood" do
    {:ok, result} = Stage.run(Keyword.put(@opts, :beats, 30))
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

  test "dialogue is laid out in screenplay columns" do
    {:ok, result} = Stage.run(Keyword.put(@opts, :beats, 24))
    assert result.script =~ "\n                      MRS. MARCHMONT\n"
    assert result.script =~ "\n                (sips the cup)\n          "
  end

  test "two stub performances are identical" do
    {:ok, a} = Stage.run(Keyword.put(@opts, :beats, 28))
    {:ok, b} = Stage.run(Keyword.put(@opts, :beats, 28))
    assert a.script == b.script
  end
end
