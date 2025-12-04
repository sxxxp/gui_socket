defmodule Socket3.Server do
  import Socket.TCP
  import Socket.Stream
  import Socket3.Tracker

  @port 1337
  defp init do
    case start_link() do
      {:ok, _} ->
        IO.puts("Tracker has started.")
        :ok

      {:error, {:already_started, _}} ->
        IO.puts("[!] start_link has already been started.")
        :error

      {:error, {reason, _}} when is_atom(reason) ->
        IO.puts("[!] Failed to start Tracker: #{inspect(reason)}")
        :error

      {:error, _} ->
        IO.puts("[?] Got unknown error.")
        :unknown_error
    end
  end

  def start do
    case Process.whereis(Socket3.Tracker) do
      nil ->
        init()

      _pid ->
        :ok
    end

    case listen(@port, packet: :line) do
      {:ok, server} ->
        IO.puts("Server listening on port #{@port}")
        IO.puts("Waiting for a client...")

        accept_loop(server)

      {:error, reason} ->
        IO.puts("[!] Failed to start server: #{inspect(reason)}")
        :error
    end
  end

  def accept_loop(server) do
    timeout = (get_count() == 0 && 180_000) || :infinity

    case accept(server, timeout: timeout) do
      {:ok, client} ->
        pid =
          spawn_link(fn ->
            IO.puts("Client connected: #{inspect(client)} - Starting new process.")
            echo_client(self(), client)
            client_close(self(), client)
          end)

        add_client(pid, client)

        accept_loop(server)

      {:error, :closed} ->
        server |> close()
        IO.puts("Server socket closed.")

      {:error, reason} ->
        server |> close()
        IO.puts("[!] Accept error: #{inspect(reason)}")
    end
  end

  def echo_client(pid, sock) do
    case sock |> recv() do
      {:ok, message} when is_bitstring(message) ->
        IO.puts("Received #{inspect(sock)} message: #{message |> String.trim_trailing()}")

        case message do
          "quit" <> _ ->
            client_close(pid, sock)
            IO.puts("#{inspect(sock)} sent 'quit'. Closing connection.")
            :ok

          _ ->
            broadcast_message(sock, message)
            echo_client(pid, sock)
        end

      {:ok, nil} ->
        client_close(pid, sock)
        IO.puts("[!] Received nil (Client #{inspect(sock)} Disconnected).")
        :ok

      {:error, :closed} ->
        client_close(pid, sock)
        IO.puts("[!] Client #{inspect(sock)} has already closed connection.")
        :ok

      {:error, reason} ->
        IO.puts("[!] Receive error: #{inspect(reason)}")
        :error
    end
  end

  defp broadcast_message(sender, data) do
    for sock <- get_clients(), sender != sock do
      sock |> Socket.Stream.send("#{inspect(sender)} sended: " <> data)
    end
  end

  defp client_close(pid, sock) do
    sock |> close()
    pid |> delete_client()
  end
end
