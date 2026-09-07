defmodule Play1.PlanTest do
  use ExUnit.Case, async: true

  alias Play1.{Cast, Plan}

  @available Cast.ids()

  test "a plan is built from the director's JSON, keeping only real, available characters" do
    json = %{
      "who" => ["arthur_pembroke", "Mrs. Marchmont", "nobody", "arthur_pembroke"],
      "where" => "the parlour",
      "time" => "moments later",
      "note" =>
        "Dr. Pembroke and Mrs. Marchmont meet Miss Vane in the parlour, who has a most unusual proposition.",
      "premise" => "Miss Vane has asked to speak with them both.",
      "arrivals" => [
        %{"who" => "clara_vane", "after_beats" => 2},
        %{"who" => "arthur_pembroke", "after_beats" => 1}
      ],
      "opening_line_by" => "helena_marchmont",
      "max_beats" => 40
    }

    plan = Plan.from_model(json, 2, @available)
    assert plan.who == [:arthur_pembroke, :helena_marchmont]
    assert plan.where == "the parlour"
    assert plan.time == "MOMENTS LATER"
    assert plan.arrivals == [%{who: :clara_vane, after_beats: 2}]
    assert plan.opening_line_by == :helena_marchmont
    assert plan.max_beats == 16
    refute plan.disruption
    assert Plan.everyone(plan) == [:arthur_pembroke, :helena_marchmont, :clara_vane]
  end

  test "naming Ambrose in the cast asks for the disruption" do
    plan =
      Plan.from_model(
        %{
          "who" => ["lavinia_ashworth", "julian_strake", "ambrose_ashworth"],
          "where" => "library"
        },
        3,
        @available
      )

    assert plan.disruption
    assert plan.where == "the library"
    refute :ambrose_ashworth in plan.who
  end

  test "an empty or useless cast falls back to the first two available" do
    plan =
      Plan.from_model(%{"who" => ["x"], "where" => "nowhere"}, 1, [
        :clara_vane,
        :julian_strake,
        :ambrose_ashworth
      ])

    assert plan.who == [:clara_vane, :julian_strake]
    assert plan.where == "the drawing-room"
  end
end
