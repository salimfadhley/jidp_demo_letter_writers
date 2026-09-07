defmodule Play1.PrivacyTest do
  use ExUnit.Case, async: true

  alias Play1.{Cast, Prompts}

  test "a character's prompt carries its own secret and game, and nobody else's" do
    for id <- Cast.ids() -- [Cast.visitor()] do
      own = Cast.initial_state(id)
      prompt = Prompts.system(own)
      assert prompt =~ own.secret
      assert prompt =~ own.game.premise

      for other <- Cast.ids() -- [id, Cast.visitor()] do
        refute prompt =~ Cast.initial_state(other).secret
        refute prompt =~ Cast.initial_state(other).game.premise
      end
    end
  end

  test "the visitor has a monologue prompt and no game discipline" do
    prompt = Prompts.system(Cast.initial_state(Cast.visitor()))
    assert prompt =~ "monologue"
    refute prompt =~ "heighten"
  end
end
