defmodule Play1.PrivacyTest do
  use ExUnit.Case, async: true

  alias Play1.{Cast, Prompts}

  test "a character's prompt carries its own secret and game, and nobody else's" do
    for id <- Cast.ids() -- Cast.visitors() do
      own = Cast.initial_state(id)
      prompt = Prompts.system(own)
      assert prompt =~ own.secret
      assert prompt =~ own.game.premise

      for other <- Cast.ids() -- [id | Cast.visitors()] do
        refute prompt =~ Cast.initial_state(other).secret
        refute prompt =~ Cast.initial_state(other).game.premise
      end
    end
  end

  test "the director is told to open on a Blavatskyite séance and to end on a denouement" do
    state = %{synopsis: [], disruption_used: false}
    first = Prompts.Director.plan(state, %{number: 1, total: 5, available: Cast.ids()})
    last = Prompts.Director.plan(state, %{number: 5, total: 5, available: Cast.ids()})
    assert first =~ "Blavatskyite"
    assert last =~ "denouement"
    assert Prompts.Director.system() =~ "weltschmerz"
  end

  test "the visitor has a monologue prompt and no game discipline" do
    prompt = Prompts.system(Cast.initial_state(Cast.visitor()))
    assert prompt =~ "monologue"
    refute prompt =~ "heighten"
  end
end
