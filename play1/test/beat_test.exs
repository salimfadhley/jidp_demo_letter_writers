defmodule Play1.BeatTest do
  use ExUnit.Case, async: true

  alias Play1.Beat

  @attrs %{
    seq: 1,
    phase: :party,
    speaker: :helena_marchmont,
    place: "the fire",
    group: [:helena_marchmont, :arthur_pembroke],
    line: "I said I would come.",
    direction: "drawing off her gloves",
    inner: "He looks tired.",
    game_move: :heighten,
    relationship: %{toward: :arthur_pembroke, trust: 1}
  }

  test "a beat carries its required fields and renders as a script line" do
    beat = Beat.new!(@attrs)
    assert Beat.to_script(beat) == "MRS. MARCHMONT. (drawing off her gloves) I said I would come."

    assert Beat.to_script(%{beat | kind: :silent, line: nil}) ==
             "(MRS. MARCHMONT drawing off her gloves.)"

    assert Beat.to_script(%{beat | kind: :aside}) =~ "(aside; drawing off her gloves)"
  end

  test "the public form hides inner thought, game move and relationship" do
    public = @attrs |> Beat.new!() |> Beat.public()
    assert public.inner == nil
    assert public.relationship == nil
    assert public.game_move == :rest
    assert public.line == "I said I would come."
  end

  test "moves parse from the model's shorthand" do
    assert Beat.parse_move(%{"to" => "join:clara_vane"}, :helena_marchmont) ==
             {:join, :clara_vane}

    assert Beat.parse_move("join:helena_marchmont", :helena_marchmont) == nil
    assert Beat.parse_move("withdraw", :helena_marchmont) == :withdraw
    assert Beat.parse_move(%{"to" => "alone"}, :helena_marchmont) == :withdraw
    assert Beat.parse_move("leave", :helena_marchmont) == :leave
    assert Beat.parse_move("elsewhere", :helena_marchmont) == nil
  end

  test "unknown kinds and moves are rejected" do
    assert_raise ArgumentError, fn -> Beat.new!(Map.put(@attrs, :kind, :sing)) end
    assert_raise ArgumentError, fn -> Beat.new!(Map.put(@attrs, :game_move, :cheat)) end
  end
end
