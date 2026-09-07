defmodule Play1.Room do
  @moduledoc """
  Who is standing where. A pure data structure the director owns: groups are
  simply the sets of people at each place. Nothing here calls a model.
  """

  alias Play1.Cast

  @type t :: %__MODULE__{
          at: %{Cast.id() => String.t()},
          departed: [Cast.id()]
        }

  defstruct at: %{}, departed: []

  @spec new() :: t()
  def new, do: %__MODULE__{}

  @doc "A character enters and stands at `place`."
  @spec enter(t(), Cast.id(), String.t()) :: t()
  def enter(%__MODULE__{} = room, id, place), do: %{room | at: Map.put(room.at, id, place)}

  @doc "Where a character is, or nil if not in the room."
  @spec place_of(t(), Cast.id()) :: String.t() | nil
  def place_of(%__MODULE__{} = room, id), do: Map.get(room.at, id)

  @doc "Everyone at a place, in cast order."
  @spec members(t(), String.t()) :: [Cast.id()]
  def members(%__MODULE__{} = room, place) do
    Enum.filter(Cast.ids(), &(Map.get(room.at, &1) == place))
  end

  @doc "All occupied places with their members, in the order of `Cast.places/0`."
  @spec groups(t()) :: [{String.t(), [Cast.id()]}]
  def groups(%__MODULE__{} = room) do
    Cast.places()
    |> Enum.map(&{&1, members(room, &1)})
    |> Enum.reject(fn {_place, members} -> members == [] end)
  end

  @doc "Everyone still present, in cast order."
  @spec present(t()) :: [Cast.id()]
  def present(%__MODULE__{} = room), do: Enum.filter(Cast.ids(), &Map.has_key?(room.at, &1))

  @doc """
  Apply a move. Joining someone puts you at their place; `:withdraw` finds an
  empty spot away from the conversation; `:leave` takes you out of the house.
  Returns the new room and the place the mover ended up (nil when they left).
  """
  @spec move(t(), Cast.id(), Play1.Beat.move()) :: {t(), String.t() | nil}
  def move(%__MODULE__{} = room, id, {:join, other}) do
    case place_of(room, other) do
      nil -> {room, place_of(room, id)}
      place -> {enter(room, id, place), place}
    end
  end

  def move(%__MODULE__{} = room, id, :withdraw) do
    place = Enum.find(Cast.places(), List.last(Cast.places()), &(members(room, &1) == []))
    {enter(room, id, place), place}
  end

  def move(%__MODULE__{} = room, id, :leave) do
    {%{room | at: Map.delete(room.at, id), departed: room.departed ++ [id]}, nil}
  end

  def move(%__MODULE__{} = room, id, nil), do: {room, place_of(room, id)}
end
