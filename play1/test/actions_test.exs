defmodule Play1.ActionsTest do
  use ExUnit.Case, async: true

  alias Play1.Actions.{HearBeat, TakeBeat}
  alias Play1.{Beat, Cast}

  @beat Beat.new!(
          seq: 3,
          phase: :party,
          speaker: :clara_vane,
          place: "the fire",
          group: [:clara_vane, :helena_marchmont],
          line: "A chill.",
          inner: "That was close.",
          game_move: :heighten
        )

  test "hearing a beat remembers only its public form" do
    state = Cast.initial_state(:helena_marchmont)
    {:ok, %{witnessed: [heard]}} = HearBeat.run(%{beat: @beat}, %{state: state})
    assert heard.line == "A chill."
    assert heard.inner == nil
    assert heard.game_move == :rest
  end

  test "taking a beat records it, applies the relationship delta, and reports the game move" do
    state = Cast.initial_state(:helena_marchmont)

    params = %{
      seq: 1,
      phase: :party,
      place: "the fire",
      group: [:helena_marchmont, :arthur_pembroke],
      cue: ""
    }

    {:ok, changes, []} = TakeBeat.run(params, %{state: state})

    assert changes.beats_spoken == 1
    assert [own] = changes.witnessed
    assert own.speaker == :helena_marchmont
    # The stub cycles play/heighten/rest/explore by beat number: beat 1 is a heighten.
    assert changes.last_game_move == :heighten
    assert changes.rung == 1

    assert changes.relationships.arthur_pembroke.trust ==
             state.relationships.arthur_pembroke.trust - 1
  end

  test "a character may not heighten twice running, nor past the top of the ladder" do
    state = %{Cast.initial_state(:helena_marchmont) | last_game_move: :heighten}
    params = %{seq: 1, phase: :party, place: "the fire", group: [:helena_marchmont], cue: ""}
    {:ok, changes, []} = TakeBeat.run(params, %{state: state})
    assert changes.last_game_move == :play
    assert changes.rung == 0

    top = %{Cast.initial_state(:helena_marchmont) | rung: 5}
    {:ok, changes, []} = TakeBeat.run(params, %{state: top})
    assert changes.last_game_move == :play
    assert changes.rung == 5
  end
end
