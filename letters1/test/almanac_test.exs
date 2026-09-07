defmodule JidoDemo1.AlmanacTest do
  use ExUnit.Case, async: true

  alias JidoDemo1.{Almanac, Cast, Prompts}

  test "each town has its own standing description and its own news" do
    assert Almanac.place("Cheltenham") =~ "spa town"
    assert Almanac.place("Bath") =~ "Roman"
    assert Almanac.place("London") =~ "fog"

    cheltenham = Almanac.context("Cheltenham", ~D[1891-10-14]).local
    bath = Almanac.context("Bath", ~D[1891-10-14]).local
    assert cheltenham != bath
    assert Enum.any?(cheltenham, &(&1 =~ "Langtry"))
  end

  test "news is released only as the calendar reaches it" do
    early = Almanac.context("London", ~D[1891-10-05])
    later = Almanac.context("London", ~D[1891-11-03])

    refute Enum.any?(early.local, &(&1 =~ "Parnell"))
    assert Enum.any?(later.local ++ later.national, &(&1 =~ "Balfour"))
    assert length(later.local) == 3
  end

  test "a character's compose prompt carries their own town's world, not another's" do
    clara = Cast.initial_state(:clara_vane)
    prompt = Prompts.compose(clara, to: :helena_marchmont, round: 1, date: ~D[1891-10-20])
    assert prompt =~ "In Bath lately"
    assert prompt =~ "mesmerist"
    refute prompt =~ "Langtry"
  end

  test "the fifth character is known to everyone but is nobody's correspondent" do
    for id <- Cast.ids() do
      assert Prompts.system(Cast.initial_state(id)) =~ Cast.outsider().name
    end

    refute Enum.any?(Cast.ids(), &(Cast.name(&1) == Cast.outsider().name))
  end
end
