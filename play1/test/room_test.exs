defmodule Play1.RoomTest do
  use ExUnit.Case, async: true

  alias Play1.Room

  test "groups are simply who is in which room" do
    room =
      Room.new()
      |> Room.enter(:lavinia_ashworth, "the hall")
      |> Room.enter(:helena_marchmont, "the drawing-room")
      |> Room.enter(:arthur_pembroke, "the drawing-room")

    assert Room.groups(room) == [
             {"the drawing-room", [:helena_marchmont, :arthur_pembroke]},
             {"the hall", [:lavinia_ashworth]}
           ]

    assert Room.members(room, "the drawing-room") == [:helena_marchmont, :arthur_pembroke]
  end

  test "joining, withdrawing and leaving" do
    room =
      Room.new()
      |> Room.enter(:helena_marchmont, "the parlour")
      |> Room.enter(:clara_vane, "the library")

    {room, "the parlour"} = Room.move(room, :clara_vane, {:join, :helena_marchmont})
    {room, away} = Room.move(room, :clara_vane, :withdraw)
    assert away != "the parlour"
    assert Room.members(room, away) == [:clara_vane]
    {room, nil} = Room.move(room, :clara_vane, :leave)
    assert Room.present(room) == [:helena_marchmont]
    assert room.departed == [:clara_vane]
  end

  test "joining someone who has left keeps you where you are" do
    room = Room.new() |> Room.enter(:helena_marchmont, "the parlour")
    assert {^room, "the parlour"} = Room.move(room, :helena_marchmont, {:join, :julian_strake})
  end
end
