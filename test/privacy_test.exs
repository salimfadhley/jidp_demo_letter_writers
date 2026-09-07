defmodule JidoDemo1.PrivacyTest do
  use ExUnit.Case, async: true

  alias JidoDemo1.{Cast, Prompts}

  test "a character's prompt contains its own secret and nobody else's" do
    for id <- Cast.ids() do
      own = Cast.initial_state(id)
      prompt = Prompts.system(own)
      assert prompt =~ own.guilty_secret

      for other <- Cast.ids() -- [id] do
        secret = Cast.initial_state(other).guilty_secret
        refute prompt =~ secret, "#{id}'s prompt leaks #{other}'s secret"
        refute prompt =~ Cast.initial_state(other).private_motivation
      end
    end
  end

  test "the compose prompt only draws on the character's own memory" do
    helena = Cast.initial_state(:helena_marchmont)
    prompt = Prompts.compose(helena, :clara_vane, 1, ~D[1891-10-14])
    refute prompt =~ Cast.initial_state(:clara_vane).guilty_secret
    assert prompt =~ "(none yet)"
  end
end
