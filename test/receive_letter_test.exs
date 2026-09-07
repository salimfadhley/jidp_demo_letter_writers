defmodule JidoDemo1.ReceiveLetterTest do
  use ExUnit.Case, async: true

  alias JidoDemo1.Actions.ReceiveLetter
  alias JidoDemo1.{Cast, Letter}

  setup do
    state = Cast.initial_state(:arthur_pembroke)

    letter =
      Letter.new!(
        id: "letter-001",
        round: 1,
        from: :helena_marchmont,
        to: :arthur_pembroke,
        date: ~D[1891-10-14],
        salutation: "My dear Dr. Pembroke,",
        body: "Can you explain what happened without cruelty?",
        valediction: "Yours sincerely,",
        concealed_intent: "Find out whether he pities me."
      )

    %{state: state, letter: letter}
  end

  test "receiving a letter stores it in memory, stripped of private fields", ctx do
    {:ok, changes, _directives} = ReceiveLetter.run(%{letter: ctx.letter}, %{state: ctx.state})

    assert [remembered] = changes.public_memory
    assert remembered.id == "letter-001"
    assert remembered.concealed_intent == nil
  end

  test "receiving a letter changes feeling toward the sender", ctx do
    before = ctx.state.relationships.helena_marchmont
    {:ok, changes, _} = ReceiveLetter.run(%{letter: ctx.letter}, %{state: ctx.state})
    after_ = changes.relationships.helena_marchmont

    assert after_ != before
    assert after_.trust == before.trust - 1
    assert after_.suspicion == before.suspicion + 1
    assert changes.fear_of_exposure == ctx.state.fear_of_exposure + 1
    assert [pressure] = changes.current_pressure
    assert pressure =~ "Mrs. Marchmont"
  end

  test "the appraisal carries the character's decision about what to do next", ctx do
    {:ok, changes, _} = ReceiveLetter.run(%{letter: ctx.letter}, %{state: ctx.state})
    # The stub has Pembroke ignore whatever Helena sends him.
    assert changes.last_appraisal.decision == %{
             action: :ignore,
             to: nil,
             purpose: "He will not dignify it."
           }
  end

  test "the private note records the appraisal", ctx do
    {:ok, changes, _} = ReceiveLetter.run(%{letter: ctx.letter}, %{state: ctx.state})
    assert [note] = changes.private_memory
    assert note =~ "holding something back"
  end

  test "with no observer, no directives are emitted", ctx do
    {:ok, _changes, directives} = ReceiveLetter.run(%{letter: ctx.letter}, %{state: ctx.state})
    assert directives == []
  end
end
