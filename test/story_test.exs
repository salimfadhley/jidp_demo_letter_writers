defmodule JidoDemo1.StoryTest do
  @moduledoc "End-to-end runs against the deterministic stub model."
  use ExUnit.Case, async: false

  alias JidoDemo1.{Cast, Story}

  @opts [out: nil, quiet: true, timeout: 10_000]

  test "a ten-letter run produces letters from all four characters in order" do
    {:ok, result} = Story.run(@opts)

    ids = Enum.map(result.entries, & &1.letter.id)
    assert ids == Enum.map(1..10, &"letter-#{String.pad_leading(Integer.to_string(&1), 3, "0")}")

    writers = result.entries |> Enum.map(& &1.letter.from) |> Enum.uniq()
    assert Enum.sort(writers) == Enum.sort(Cast.ids())

    scripted = result.entries |> Enum.take(8) |> Enum.map(&{&1.letter.from, &1.letter.to})
    assert scripted == Story.opening()

    assert Enum.all?(result.entries, &(&1.appraisal != nil))
    assert result.report =~ "THE ETHERIDGE CIRCLE, 1891"
    assert result.report =~ "DEBUG: PRIVATE STATE CHANGES"
    assert result.report =~ "SUMMARY: HOW THE CIRCLE SHIFTED"
  end

  test "agents never receive another agent's concealed intent" do
    {:ok, result} = Story.run(Keyword.put(@opts, :letters, 4))

    for {id, state} <- result.final,
        letter <- state.public_memory,
        letter.from != id do
      assert letter.concealed_intent == nil
      assert letter.private_note == nil
    end
  end

  test "relationships move as a result of correspondence" do
    {:ok, result} = Story.run(Keyword.put(@opts, :letters, 4))
    helena_before = result.initial.helena_marchmont.relationships.arthur_pembroke
    helena_after = result.final.helena_marchmont.relationships.arthur_pembroke
    assert helena_after.trust < helena_before.trust
    assert helena_after.suspicion > helena_before.suspicion
  end

  test "two runs with the stub are identical" do
    {:ok, first} = Story.run(Keyword.put(@opts, :letters, 6))
    {:ok, second} = Story.run(Keyword.put(@opts, :letters, 6))

    strip = fn entries -> Enum.map(entries, &{&1.letter.from, &1.letter.to, &1.letter.body}) end
    assert strip.(first.entries) == strip.(second.entries)
    assert first.final == second.final
  end
end
