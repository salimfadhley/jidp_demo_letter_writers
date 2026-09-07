defmodule JidoDemo1.ChooseCorrespondentTest do
  use ExUnit.Case, async: true

  alias JidoDemo1.Actions.ChooseCorrespondent
  alias JidoDemo1.{Cast, Letter}

  test "an unanswered letter pulls the choice toward its writer" do
    state =
      :helena_marchmont
      |> Cast.initial_state()
      |> Map.merge(%{public_memory: [], last_recipient: nil})

    from_strake =
      Letter.new!(
        id: "letter-001",
        round: 1,
        from: :julian_strake,
        to: :helena_marchmont,
        date: ~D[1891-10-14],
        salutation: "Dear Mrs. Marchmont,",
        body: "...",
        valediction: "Yours,"
      )

    # With nothing received, Helena is drawn to whoever she feels most about: Pembroke.
    assert ChooseCorrespondent.choose(state) == :arthur_pembroke
    # An unanswered letter from Strake outweighs that.
    assert ChooseCorrespondent.choose(%{state | public_memory: [from_strake]}) == :julian_strake
  end

  test "the last recipient is avoided" do
    state =
      :helena_marchmont
      |> Cast.initial_state()
      |> Map.merge(%{public_memory: [], last_recipient: :arthur_pembroke})

    assert ChooseCorrespondent.choose(state) == :clara_vane
  end
end
