defmodule BrothTest.Chat.SendMsgTest do
  use ExUnit.Case, async: true
  use KousaTest.Support.EctoSandbox

  alias Beef.Schemas.User
  alias Beef.Users
  alias BrothTest.WsClient
  alias BrothTest.WsClientFactory
  alias KousaTest.Support.Factory

  require WsClient

  setup do
    user = Factory.create(User)
    client_ws = WsClientFactory.create_client_for(user)

    {:ok, user: user, client_ws: client_ws}
  end

  describe "the websocket chat:send_msg operation" do
    @text_token [%{"t" => "text", "v" => "foobar"}]

    test "sends a message to the room", t do
      # first, create a room owned by the primary user.
      {:ok, %{room: %{id: room_id}}} = Kousa.Room.create_room(t.user.id, "foo room", "foo", false)
      # make sure the user is in there.
      assert %{currentRoomId: ^room_id} = Users.get_by_id(t.user.id)

      # create a user that is logged in.
      listener = %{id: listener_id} = Factory.create(User)
      listener_ws = WsClientFactory.create_client_for(listener)

      # join the speaker user into the room
      Kousa.Room.join_room(listener_id, room_id)
      WsClient.assert_frame("new_user_join_room", _)

      WsClient.send_msg(t.client_ws, "chat:send_msg", %{"tokens" => @text_token})

      WsClient.assert_frame(
        "new_chat_msg",
        %{"msg" => %{"tokens" => @text_token}},
        t.client_ws
      )

      WsClient.assert_frame(
        "new_chat_msg",
        %{"msg" => %{"tokens" => @text_token}},
        listener_ws
      )
    end

    @tag :skip
    test "won't send an invalid token over."

    test "can be used to send a whispered message", t do
      # first, create a room owned by the primary user.
      {:ok, %{room: %{id: room_id}}} = Kousa.Room.create_room(t.user.id, "foo room", "foo", false)
      # make sure the user is in there.
      assert %{currentRoomId: ^room_id} = Users.get_by_id(t.user.id)

      # create a user that is logged in.
      listener = %{id: listener_id} = Factory.create(User)
      listener_ws = WsClientFactory.create_client_for(listener)

      # create a user that is logged in.
      whispener = %{id: whispener_id} = Factory.create(User)
      whispener_ws = WsClientFactory.create_client_for(whispener)

      # join the speaker user into the room
      Kousa.Room.join_room(listener_id, room_id)
      Kousa.Room.join_room(whispener_id, room_id)
      WsClient.assert_frame("new_user_join_room", _)
      WsClient.assert_frame("new_user_join_room", _)

      WsClient.send_msg(t.client_ws, "chat:send_msg", %{
        "tokens" => @text_token,
        "whisperedTo" => [whispener_id]
      })

      WsClient.assert_frame(
        "new_chat_msg",
        %{"msg" => %{"tokens" => @text_token}},
        t.client_ws
      )

      WsClient.assert_frame(
        "new_chat_msg",
        %{"msg" => %{"tokens" => @text_token}},
        whispener_ws
      )

      WsClient.refute_frame(
        "new_chat_msg",
        listener_ws
      )
    end
  end
end
