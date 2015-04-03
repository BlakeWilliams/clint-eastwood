defmodule Clint.Eastwood do
  def start({host, port}) do
    {:ok, socket} = Socket.TCP.connect(host, port, packet: :line)

    listen(socket, %{})
  end

  def listen(socket, state, name \\ "Clint") do
    raw_body =
      Socket.Stream.recv!(socket)

    body = raw_body |> to_string |> JSX.decode!
    event = body["event"]

    case event do
      "get_name" -> Socket.Stream.send!(socket, "#{name}\n")
      "game_start" -> state = body
      "choice" -> Socket.Stream.send!(socket, choice(state, body))
      "hole" -> state = Map.put(state, "cards", body["cards"])
      "showdown" -> IO.puts "Do you feel lucky, punk?"
      _ -> true # IO.puts "Ignoring #{event}"
    end

    __MODULE__.listen(socket, state)
  end

  def choice(state, body) do
    table_cards = get_table_cards(body)
    cards = Map.get(state, "cards")

    if Enum.member?(cards, "AS") do
      IO.puts "THE ACE OF SPADES, THE ACE OF SPADES"
      val = "RAISE"
    else
      strength = hand_strength_for(cards ++ table_cards)

      IO.puts "STRENGTH: #{strength}"
      val = cond do
        strength > 9 -> "RAISE"
        strength > 6 -> "CALL"
        true -> "FOLD"
      end
    end

    IO.puts "Doing: #{val}"
    "#{val}\n"
  end

  def hand_strength_for(cards) do
    cards = Enum.map(cards, fn (card) ->
      [face, suit] = String.split(card, "", parts: 2)
      {face, suit}
    end)

    face_matches = Enum.group_by(cards, fn ({face, _}) ->
      face
    end) |> Map.values |> Enum.map(&length/1) |> Enum.max

    suit_matches = Enum.group_by(cards, fn ({_, suit}) ->
      suit
    end) |> Map.values |> Enum.map(&length/1) |> Enum.max

    remaining_draws = 7 - length(cards)

    score = (4 * (face_matches - 1)) + (suit_matches - 1) + remaining_draws

    Enum.map(cards, fn ({face, suit}) ->
      face <> suit
    end) |> Enum.join(",") |> IO.puts
    IO.puts "Score: #{score}\n"
    score
  end


  defp get_table_cards(body) do
    table = Map.get(body, "table")
    flop = Map.get(table, "flop")
    turn = Map.get(table, "turn")
    river = Map.get(table, "river")
    List.wrap(flop) ++ List.wrap(turn) ++ List.wrap(river)
  end
end
