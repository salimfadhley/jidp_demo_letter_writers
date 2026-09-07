defmodule JidoDemo1.LLMTest do
  use ExUnit.Case, async: true

  alias JidoDemo1.LLM

  test "decodes clean JSON and fenced JSON" do
    assert {:ok, %{"a" => 1}} = LLM.decode_json(~s({"a": 1}))
    assert {:ok, %{"a" => 1}} = LLM.decode_json("```json\n{\"a\": 1}\n```")
  end

  test "repairs raw newlines inside string values" do
    broken = "{\"body\": \"first paragraph.\n\nsecond paragraph.\", \"n\": 2}"

    assert {:ok, %{"body" => "first paragraph.\n\nsecond paragraph.", "n" => 2}} =
             LLM.decode_json(broken)
  end

  test "leaves escaped quotes and existing escapes alone" do
    text = ~s({"body": "she said \\"no\\".\\nAnd left."})
    assert LLM.repair_control_characters(text) == text
    assert {:ok, %{"body" => "she said \"no\".\nAnd left."}} = LLM.decode_json(text)
  end

  test "rejects text with no JSON object" do
    assert {:error, {:invalid_json, _}} = LLM.decode_json("I would rather not.")
  end
end
