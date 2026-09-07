defmodule Play1.Beat do
  @moduledoc """
  One beat of the play: a character speaks a line and/or performs an action.

  `inner`, `game_move` and `relationship` are the speaker's private business.
  `public/1` strips them before the beat is delivered to anyone else.
  """

  alias Play1.Cast

  @kinds [:speak, :aside, :silent, :monologue]
  @game_moves [:play, :heighten, :explore, :rest]
  @required [:seq, :phase, :speaker, :place, :group]

  @enforce_keys @required
  defstruct @required ++
              [
                kind: :speak,
                line: nil,
                direction: nil,
                addressed_to: nil,
                game_move: :rest,
                rung: 0,
                inner: nil,
                move: nil,
                relationship: nil
              ]

  @type move :: {:join, Cast.id()} | :withdraw | :leave

  @type t :: %__MODULE__{
          seq: pos_integer(),
          phase: :arrivals | :party | :departures,
          speaker: Cast.id(),
          place: String.t(),
          group: [Cast.id()],
          kind: :speak | :aside | :silent | :monologue,
          line: String.t() | nil,
          direction: String.t() | nil,
          addressed_to: Cast.id() | nil,
          game_move: :play | :heighten | :explore | :rest,
          rung: non_neg_integer(),
          inner: String.t() | nil,
          move: move() | nil,
          relationship: map() | nil
        }

  @spec kinds() :: [atom()]
  def kinds, do: @kinds

  @spec game_moves() :: [atom()]
  def game_moves, do: @game_moves

  @doc "Build a beat, raising on a missing required field or an unknown kind or game move."
  @spec new!(map() | keyword()) :: t()
  def new!(attrs) do
    beat = struct!(__MODULE__, attrs)
    unless beat.kind in @kinds, do: raise(ArgumentError, "unknown kind #{inspect(beat.kind)}")

    unless beat.game_move in @game_moves,
      do: raise(ArgumentError, "unknown game move #{inspect(beat.game_move)}")

    beat
  end

  @doc "Build a beat from the model's JSON plus the fields the director and speaker control."
  @spec from_model(map(), keyword()) :: t()
  def from_model(json, fields) do
    speaker = Keyword.fetch!(fields, :speaker)

    new!(
      seq: Keyword.fetch!(fields, :seq),
      phase: Keyword.fetch!(fields, :phase),
      speaker: speaker,
      place: Keyword.fetch!(fields, :place),
      group: Keyword.fetch!(fields, :group),
      kind: kind(json["kind"], json["line"]),
      line: blank_to_nil(json["line"]),
      direction: blank_to_nil(json["direction"]),
      addressed_to: Cast.parse_id(json["addressed_to"], except: speaker),
      game_move: game_move(json["game_move"]),
      rung: Keyword.get(fields, :rung, 0),
      inner: blank_to_nil(json["inner"]),
      move: parse_move(json["move"], speaker),
      relationship: relationship(json["relationship"], speaker)
    )
  end

  @doc "The beat as everyone else in the room perceives it."
  @spec public(t() | map()) :: t()
  def public(%__MODULE__{} = beat),
    do: %{beat | inner: nil, relationship: nil, game_move: :rest, rung: 0}

  def public(map) when is_map(map), do: map |> to_struct() |> public()

  @doc "Rebuild a struct from a plain map (as it may arrive inside a signal)."
  @spec to_struct(map()) :: t()
  def to_struct(%__MODULE__{} = beat), do: beat

  def to_struct(map) when is_map(map),
    do: struct!(__MODULE__, Map.new(map, fn {k, v} -> {to_atom(k), v} end))

  @doc "Parse a move as the model writes it: `join:<id>`, `withdraw`, `leave`."
  @spec parse_move(term(), Cast.id()) :: move() | nil
  def parse_move(%{"to" => to}, speaker), do: parse_move(to, speaker)
  def parse_move("withdraw", _speaker), do: :withdraw
  def parse_move("alone", _speaker), do: :withdraw
  def parse_move("leave", _speaker), do: :leave

  def parse_move("join:" <> id, speaker) do
    case Cast.parse_id(id, except: speaker) do
      nil -> nil
      other -> {:join, other}
    end
  end

  def parse_move(_, _speaker), do: nil

  @doc "The line as it appears in the script, e.g. `MRS. MARCHMONT. (drawing off her gloves) I said I would come.`"
  @spec to_script(t()) :: String.t()
  def to_script(%__MODULE__{} = beat) do
    name = Cast.stage_name(beat.speaker)
    direction = beat.direction && String.trim_trailing(String.trim(beat.direction), ".")

    case beat.kind do
      :silent ->
        "(#{name} #{direction || "says nothing"}.)"

      :aside ->
        "#{name}. (aside#{if direction, do: "; " <> direction, else: ""}) #{beat.line}"

      _ ->
        "#{name}.#{if direction, do: " (" <> direction <> ")", else: ""} #{beat.line}"
    end
  end

  defp kind(value, line) do
    case {to_string(value || "") |> String.downcase(), line} do
      {"aside", _} -> :aside
      {"monologue", _} -> :monologue
      {"silent", _} -> :silent
      {_, nil} -> :silent
      {_, ""} -> :silent
      _ -> :speak
    end
  end

  defp game_move(value) do
    case to_string(value || "") |> String.downcase() do
      "heighten" -> :heighten
      "explore" -> :explore
      "play" -> :play
      _ -> :rest
    end
  end

  defp relationship(%{} = json, speaker) do
    case Cast.parse_id(json["toward"], except: speaker) do
      nil ->
        nil

      toward ->
        %{
          toward: toward,
          trust: clamp(json["trust"]),
          suspicion: clamp(json["suspicion"]),
          affection: clamp(json["affection"]),
          resentment: clamp(json["resentment"])
        }
    end
  end

  defp relationship(_, _), do: nil

  defp clamp(v) when is_integer(v), do: v |> max(-2) |> min(2)
  defp clamp(v) when is_float(v), do: v |> round() |> clamp()
  defp clamp(_), do: 0

  defp blank_to_nil(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      text -> text
    end
  end

  defp blank_to_nil(_), do: nil

  defp to_atom(v) when is_atom(v), do: v
  defp to_atom(v) when is_binary(v), do: String.to_existing_atom(v)
end
