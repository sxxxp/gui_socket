defmodule Socket.Client do
  def connect do
    case Socket.TCP.connect("127.0.0.1", 1337, packet: :line) do
      {:ok, client} ->
        receiver = spawn_link(fn -> client |> handle_recv(self()) end)
        client |> handle_send(receiver)
        client |> Socket.Stream.close()
        :ok

      {:error, reason} ->
        IO.puts("[!] Failed to connect: #{inspect(reason)}")
        :error
    end
  end

  defp handle_send(client, receiver) do
    message = IO.gets("enter to send message: ")

    receive do
      :done ->
        IO.puts("Receiver process done. Stopping send loop.")
        :error

      :error ->
        IO.puts("Receiver process reported an error. Stopping send loop.")
        :error

      :unknown ->
        IO.puts("Receiver process reported an unknown response. Stopping send loop.")
        :error

      _ ->
        :error
    after
      0 -> :ok
    end
    |> case do
      :error ->
        :error

      :ok ->
        case client |> Socket.Stream.send(message) do
          :ok ->
            if message != "quit\n" do
              handle_send(client, receiver)
            else
              IO.puts("Good bye!")
              send(receiver, :done)
              :ok
            end

          {:error, reason} ->
            IO.puts("[!] Send error: #{inspect(reason)}")
            send(receiver, :error)
        end
    end
  end

  defp handle_recv(client, sender) do
    receive do
      :error ->
        :error

      :done ->
        :done

      _ ->
        :error
    after
      0 -> :ok
    end
    |> case do
      :error ->
        :error

      :done ->
        :done

      :ok ->
        case client |> Socket.Stream.recv() do
          {:ok, message} when is_bitstring(message) ->
            IO.puts(message |> String.trim_trailing())
            handle_recv(client, sender)

          {:ok, nil} ->
            IO.puts("[!] Received nil (Server Disconnected).")
            send(sender, :done)
            :ok

          {:error, :closed} ->
            IO.puts("[!] Connection closed by server.")
            send(sender, :done)
            :ok

          {:error, reason} ->
            send(sender, :error)
            IO.puts("[!] Receive error: #{inspect(reason)}")
            :error

          a ->
            send(sender, :unknown)
            IO.puts("[!] Unknown response: #{inspect(a)}")
            :ok
        end
    end
  end
end
