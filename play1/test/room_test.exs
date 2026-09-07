defmodule Play1.RoomTest do
  use ExUnit.Case, async: true

  alias Play1.Room

  test "groups are simply who stands where" do
    room =
      Room.new()
      |> Room.enter(:lavinia_ashworth, "the door to the hall")
      |> Room.enter(:helena_marchmont, "the fire")
      |> Room.enter(:arthur_pembroke, "the fire")

    assert Room.groups(room) == [
             {"the fire", [:helena_marchmont, :arthur_pembroke]},
             {"the door to the hall", [:lavinia_ashworth]}
           ]

    assert Room.members(room, "the fire") == [:helena_marchmont, :arthur_pembroke]
  end

  test "joining, withdrawing and leaving" do
    room =
      Room.new()
      |> Room.enter(:helena_marchmont, "the fire")
      |> Room.enter(:clara_vane, "the window")

    {room, "the fire"} = Room.move(room, :clara_vane, {:join, :helena_marchmont})
    {room, away} = Room.move(room, :clara_vane, :withdraw)
    assert away != "the fire"
    assert Room.members(room, away) == [:clara_vane]
    {room, nil} = Room.move(room, :clara_vane, :leave)
    assert Room.present(room) == [:helena_marchmont]
    assert room.departed == [:clara_vane]
  end

  test "joining someone who has left keeps you where you are" do
    room = Room.new() |> Room.enter(:helena_marchmont, "the fire")
    assert {^room, "the fire"} = Room.move(room, :helena_marchmont, {:join, :julian_strake})
  end
end
