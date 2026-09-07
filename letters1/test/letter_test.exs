defmodule JidoDemo1.LetterTest do
  use ExUnit.Case, async: true

  alias JidoDemo1.Letter

  @attrs %{
    id: "letter-001",
    round: 1,
    from: :helena_marchmont,
    to: :arthur_pembroke,
    date: ~D[1891-10-14],
    salutation: "My dear Dr. Pembroke,",
    body: "I hardly know how to begin.",
    valediction: "I remain, yours sincerely,",
    concealed_intent: "To find out what he has heard.",
    private_note: "Wrote to Pembroke."
  }

  test "a letter carries every required field" do
    letter = Letter.new!(@attrs)

    for field <- Letter.required_fields() do
      refute is_nil(Map.fetch!(letter, field)), "#{field} should be set"
    end

    assert letter.emotional_tone in Letter.tones()
  end

  test "a letter without a required field cannot be built" do
    assert_raise ArgumentError, fn -> Letter.new!(Map.delete(@attrs, :body)) end
  end

  test "an unknown tone is rejected" do
    assert_raise ArgumentError, fn -> Letter.new!(Map.put(@attrs, :emotional_tone, :smug)) end
  end

  test "the public form hides the sender's private fields" do
    public = @attrs |> Letter.new!() |> Letter.public()
    assert public.concealed_intent == nil
    assert public.private_note == nil
    assert public.body == @attrs.body
  end

  test "renders in the period format with place, date, salutation and signature" do
    text = @attrs |> Letter.new!() |> Letter.to_text()
    assert text =~ "Cheltenham\n14 October 1891\n\nMy dear Dr. Pembroke,"
    assert String.ends_with?(String.trim(text), "Helena Marchmont")
  end

  test "a valediction repeated at the end of the body is printed once" do
    attrs = Map.put(@attrs, :body, "I hardly know how to begin.\n\nI remain, yours sincerely,")
    text = attrs |> Letter.new!() |> Letter.to_text()
    assert length(String.split(text, "I remain, yours sincerely,")) == 2
  end

  test "round-trips through a plain map with string keys" do
    map =
      @attrs |> Letter.new!() |> Map.from_struct() |> Map.new(fn {k, v} -> {to_string(k), v} end)

    assert Letter.to_struct(map) == Letter.new!(@attrs)
  end
end
