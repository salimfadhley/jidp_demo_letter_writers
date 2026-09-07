defmodule JidoDemo1.Letter do
  @moduledoc """
  A letter as structured data.

  `concealed_intent` and `private_note` belong to the sender alone. `public/1`
  strips them before a letter is delivered, so a recipient never sees them.
  """

  alias JidoDemo1.Cast

  @tones [:restrained, :pleading, :accusatory, :flirtatious, :evasive, :confessional]
  @required [:id, :round, :from, :to, :date, :salutation, :body, :valediction]

  @enforce_keys @required
  defstruct @required ++
              [
                visible_claims: [],
                emotional_tone: :restrained,
                concealed_intent: nil,
                references: [],
                private_note: nil
              ]

  @type tone :: :restrained | :pleading | :accusatory | :flirtatious | :evasive | :confessional

  @type t :: %__MODULE__{
          id: String.t(),
          round: pos_integer(),
          from: Cast.id(),
          to: Cast.id(),
          date: Date.t(),
          salutation: String.t(),
          body: String.t(),
          valediction: String.t(),
          visible_claims: [String.t()],
          emotional_tone: tone(),
          concealed_intent: String.t() | nil,
          references: [String.t()],
          private_note: String.t() | nil
        }

  @doc "Fields every letter must carry."
  @spec required_fields() :: [atom()]
  def required_fields, do: @required

  @doc "Permitted emotional tones."
  @spec tones() :: [tone()]
  def tones, do: @tones

  @doc "Build a letter, raising if a required field is missing or the tone is unknown."
  @spec new!(map() | keyword()) :: t()
  def new!(attrs) do
    letter = struct!(__MODULE__, attrs)

    unless letter.emotional_tone in @tones do
      raise ArgumentError, "unknown emotional tone #{inspect(letter.emotional_tone)}"
    end

    letter
  end

  @doc "Build a letter from the JSON the model returned plus the fields the sender controls."
  @spec from_model(map(), keyword()) :: t()
  def from_model(json, fields) do
    new!(
      id: Keyword.fetch!(fields, :id),
      round: Keyword.fetch!(fields, :round),
      from: Keyword.fetch!(fields, :from),
      to: Keyword.fetch!(fields, :to),
      date: Keyword.fetch!(fields, :date),
      salutation: text(json, "salutation", "Dear Sir or Madam,"),
      body: text(json, "body", ""),
      valediction: text(json, "valediction", "Yours faithfully,"),
      visible_claims: strings(json, "visible_claims"),
      emotional_tone: tone(json["emotional_tone"]),
      concealed_intent: json["concealed_intent"],
      references: strings(json, "references"),
      private_note: json["private_note"]
    )
  end

  @doc "The letter as the recipient is allowed to see it."
  @spec public(t() | map()) :: t()
  def public(%__MODULE__{} = letter), do: %{letter | concealed_intent: nil, private_note: nil}
  def public(map) when is_map(map), do: map |> to_struct() |> public()

  @doc "Rebuild a struct from a plain map (as it may arrive inside a signal)."
  @spec to_struct(map()) :: t()
  def to_struct(%__MODULE__{} = letter), do: letter

  def to_struct(map) when is_map(map) do
    map
    |> Map.new(fn {k, v} -> {to_atom(k), v} end)
    |> Map.update(:date, nil, &to_date/1)
    |> Map.update(:emotional_tone, :restrained, &tone/1)
    |> Map.update(:from, nil, &to_atom/1)
    |> Map.update(:to, nil, &to_atom/1)
    |> new!()
  end

  @doc "Render the letter as it would appear on the page."
  @spec to_text(t()) :: String.t()
  def to_text(%__MODULE__{} = letter) do
    valediction = String.trim(letter.valediction)

    """
    #{Cast.location(letter.from)}
    #{format_date(letter.date)}

    #{letter.salutation}

    #{letter.body |> String.trim() |> without_trailing(valediction)}

    #{valediction}
    #{Cast.signature(letter.from)}
    """
  end

  # Models sometimes end the body with the valediction as well as returning it
  # separately; print it once.
  defp without_trailing(body, valediction) do
    if valediction != "" and String.ends_with?(body, valediction) do
      body |> String.trim_trailing(valediction) |> String.trim()
    else
      body
    end
  end

  @doc "A date in the style of the period, e.g. `14 October 1891`."
  @spec format_date(Date.t()) :: String.t()
  def format_date(%Date{} = date), do: Calendar.strftime(date, "%-d %B %Y")

  defp text(json, key, default) do
    case json[key] do
      value when is_binary(value) and value != "" -> value
      _ -> default
    end
  end

  defp strings(json, key) do
    case json[key] do
      list when is_list(list) -> Enum.filter(list, &is_binary/1)
      _ -> []
    end
  end

  defp tone(value) when is_atom(value) and value in @tones, do: value

  defp tone(value) when is_binary(value) do
    case Enum.find(@tones, &(Atom.to_string(&1) == String.downcase(value))) do
      nil -> :restrained
      found -> found
    end
  end

  defp tone(_), do: :restrained

  defp to_atom(value) when is_atom(value), do: value
  defp to_atom(value) when is_binary(value), do: String.to_existing_atom(value)

  defp to_date(%Date{} = date), do: date
  defp to_date(value) when is_binary(value), do: Date.from_iso8601!(value)
end
