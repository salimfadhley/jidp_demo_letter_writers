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

    assert Enum.all?(result.entries, &(&1.appraisal != nil))
    assert result.report =~ "THE ETHERIDGE CIRCLE, 1891"
    assert result.report =~ "DEBUG: PRIVATE STATE CHANGES"
    assert result.report =~ "SUMMARY: HOW THE CIRCLE SHIFTED"
  end

  test "the characters' decisions drive who writes next" do
    {:ok, result} = Story.run(Keyword.put(@opts, :letters, 5))
    pairs = Enum.map(result.entries, &{&1.letter.from, &1.letter.to})

    # Seed: Helena to Pembroke. Pembroke ignores her, so Clara (next in cast order) is
    # invited and picks Strake. Strake decides to write to Pembroke, who decides to warn
    # Helena, who takes it to Clara. The stub's fixed choices, but the director follows them.
    assert pairs == [
             {:helena_marchmont, :arthur_pembroke},
             {:clara_vane, :julian_strake},
             {:julian_strake, :arthur_pembroke},
             {:arthur_pembroke, :helena_marchmont},
             {:helena_marchmont, :clara_vane}
           ]

    [first, second, third | _] = result.entries
    assert first.origin =~ "Mrs. Ashworth's invitation"
    assert first.appraisal.decision.action == :ignore
    assert second.origin =~ "unprompted"
    assert second.origin =~ "had not yet written or received"

    assert second.appraisal.decision == %{
             action: :write,
             to: :arthur_pembroke,
             purpose: "To provoke the doctor."
           }

    assert third.origin =~ "decision on reading letter-002"
  end

  test "a scripted opening overrides decisions until it runs out" do
    {:ok, result} = Story.run(Keyword.merge(@opts, letters: 10, opening: true))
    pairs = Enum.map(result.entries, &{&1.letter.from, &1.letter.to})

    assert Enum.take(pairs, 8) == Story.opening()
    assert Enum.all?(Enum.take(result.entries, 8), &(&1.origin == "scripted opening"))

    # Decisions made during the script were queued, newest per character replacing older:
    # Clara's on letter 4, Strake's on letter 5, Helena's on letter 6, Pembroke's on letter 7.
    assert Enum.at(pairs, 8) == {:clara_vane, :julian_strake}
    assert Enum.at(result.entries, 8).origin =~ "decision on reading letter-004"
    assert Enum.at(pairs, 9) == {:helena_marchmont, :clara_vane}
    assert Enum.at(result.entries, 9).origin =~ "decision on reading letter-006"
  end

  test "a character left out of the correspondence is invited to write" do
    {:ok, result} = Story.run(Keyword.put(@opts, :letters, 8))
    writers_and_readers = Enum.flat_map(result.entries, &[&1.letter.from, &1.letter.to])
    assert Enum.sort(Enum.uniq(writers_and_readers)) == Enum.sort(Cast.ids())
    assert Enum.any?(result.entries, &(&1.origin =~ "unprompted"))
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
    # Pembroke receives the seed letter from Helena.
    before = result.initial.arthur_pembroke.relationships.helena_marchmont
    after_ = result.final.arthur_pembroke.relationships.helena_marchmont
    assert after_.trust < before.trust
    assert after_.suspicion > before.suspicion
  end

  test "two runs with the stub are identical" do
    {:ok, first} = Story.run(Keyword.put(@opts, :letters, 6))
    {:ok, second} = Story.run(Keyword.put(@opts, :letters, 6))

    strip = fn entries -> Enum.map(entries, &{&1.letter.from, &1.letter.to, &1.letter.body}) end
    assert strip.(first.entries) == strip.(second.entries)
    assert first.final == second.final
  end
end
