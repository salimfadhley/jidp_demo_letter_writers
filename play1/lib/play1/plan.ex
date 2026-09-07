defmodule Play1.Plan do
  @moduledoc """
  A director's plan for one scene: who is in it, where, what the premise is,
  the note that heads the scene in the script, and how the scene may grow.
  """

  alias Play1.Cast

  @enforce_keys [:number, :who, :where, :premise, :note]
  defstruct [
    :number,
    :who,
    :where,
    :premise,
    :note,
    time: "LATER",
    dramatic_goal: nil,
    opening_line_by: nil,
    arrivals: [],
    disruption: false,
    max_beats: 10
  ]

  @type arrival :: %{who: Cast.id(), after_beats: pos_integer()}

  @type t :: %__MODULE__{
          number: pos_integer(),
          who: [Cast.id()],
          where: String.t(),
          premise: String.t(),
          note: String.t(),
          time: String.t(),
          dramatic_goal: String.t() | nil,
          opening_line_by: Cast.id() | nil,
          arrivals: [arrival()],
          disruption: boolean(),
          max_beats: pos_integer()
        }

  @doc "Build a plan from the director's JSON, discarding anything invalid; `available` are the characters still in the house."
  @spec from_model(map(), pos_integer(), [Cast.id()]) :: t()
  def from_model(json, number, available) do
    who =
      json["who"]
      |> List.wrap()
      |> Enum.map(&Cast.parse_id/1)
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()
      |> Enum.filter(&(&1 in available and &1 != Cast.visitor()))

    who = if length(who) >= 2, do: who, else: Enum.take(available -- [Cast.visitor()], 2)

    arrivals =
      json["arrivals"]
      |> List.wrap()
      |> Enum.map(fn
        %{"who" => id} = a ->
          found = Cast.parse_id(id)

          cond do
            is_nil(found) -> nil
            found in who -> nil
            found not in available -> nil
            found == Cast.visitor() -> nil
            true -> %{who: found, after_beats: max(to_int(a["after_beats"], 4), 1)}
          end

        _ ->
          nil
      end)
      |> Enum.reject(&is_nil/1)

    disruption =
      json["disruption"] == true or
        Cast.visitor() in Enum.map(List.wrap(json["who"]), &Cast.parse_id/1)

    %__MODULE__{
      number: number,
      who: who,
      where: Cast.parse_room(json["where"]) || hd(Cast.rooms()),
      premise: text(json["premise"], "The company talks."),
      note: text(json["note"], "#{names(who)}, #{json["where"] || "in the drawing-room"}."),
      time: json["time"] |> text("LATER") |> String.upcase(),
      dramatic_goal: text(json["dramatic_goal"], nil),
      opening_line_by:
        Cast.parse_id(json["opening_line_by"]) |> then(&if(&1 in who, do: &1, else: nil)),
      arrivals: arrivals,
      disruption: disruption,
      max_beats: json["max_beats"] |> to_int(10) |> max(4) |> min(16)
    }
  end

  @doc "Everyone the plan brings on stage, in order of appearance."
  @spec everyone(t()) :: [Cast.id()]
  def everyone(%__MODULE__{} = plan), do: plan.who ++ Enum.map(plan.arrivals, & &1.who)

  defp names(ids), do: ids |> Enum.map(&Cast.short_name/1) |> Enum.join(", ")

  defp text(value, default) when is_binary(value) do
    case String.trim(value) do
      "" -> default
      t -> t
    end
  end

  defp text(_, default), do: default

  defp to_int(v, _default) when is_integer(v), do: v
  defp to_int(v, _default) when is_float(v), do: round(v)
  defp to_int(_, default), do: default
end
