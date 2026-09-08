defmodule Play1.LLMTest do
  use ExUnit.Case, async: false

  alias Play1.LLM

  defmodule Flaky do
    @behaviour Play1.LLM
    def complete(_s, _u, opts) do
      send(:llm_test, {:called, Keyword.get(opts, :max_tokens)})

      case Process.get(:flaky_calls, 0) do
        0 ->
          Process.put(:flaky_calls, 1)
          {:error, {:truncated, ""}}

        _ ->
          {:ok, ~s({"ok": true})}
      end
    end
  end

  test "a truncated reply is asked for again with a larger budget" do
    Process.register(self(), :llm_test)
    Application.put_env(:play1, :llm_client, Flaky)

    try do
      assert {:ok, %{"ok" => true}} = LLM.complete_json("s", "u", max_tokens: 1000)
      assert_received {:called, 1000}
      assert_received {:called, 2000}
    after
      Application.put_env(:play1, :llm_client, Play1.LLM.Stub)
    end
  end

  test "repairs raw newlines inside string values" do
    assert {:ok, %{"body" => "a\n\nb"}} = LLM.decode_json("{\"body\": \"a\n\nb\"}")
  end
end
