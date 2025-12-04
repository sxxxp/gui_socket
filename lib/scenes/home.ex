defmodule Gui.Scene.Home do
  use Scenic.Scene
  require Logger

  alias Scenic.Graph
  import Scenic.Primitives
  import Scenic.Components

  @text_size 20
  @host "127.0.0.1"
  @port 1337

  @info "hi! welcome to Socket Server!
      IP address: #{@host}
      Port: #{@port}"

  @graph Graph.build(font: :roboto, font_size: @text_size)
         |> add_specs_to_graph([
           text_spec(@info, translate: {20, 20}),
           rect_spec({800, 1080}),
           text_spec("Chat Log\n", translate: {400,200}, text_align: :center,id: :chat_log)
         ])
         |> text_field("", hint: "Enter Message", id: :text_id, focus: true, translate: {20, 100})
         |> rect({50, 30},
           fill: :light_gray,
           id: :submit_button,
           input: :cursor_button,
           translate: {330, 100}
         )

  defp graph(), do: @graph

  def init(scene, _param, _opts) do
    case connect(self()) do
      {client} ->
        scene =
          scene
          |> assign(log: :queue.new(), chat: "", focus: true, client: client)
          |> push_graph(graph())

        {:ok, scene}

      {:error} ->
        :error
    end
  end

  # 버튼 클릭 시 메시지 서버로 전송
  def handle_input(
        {:cursor_button, {:btn_left, down, _, _}},
        :submit_button,
        %{assigns: %{chat: chat, log: log, focus: focus, client: client}} = scene
      ) do

    if chat != "" and down == 1 do
      queue = :queue.in({self(), chat}, log)
      client |> Socket.Stream.send(chat <> "\n")
      list = :queue.to_list(queue)
      text = list |> Enum.map(fn
        {sender, message} when sender != self() -> "#{sender}: #{message}"
        {sender, message} when sender == self() -> "me: #{message}"
        _ -> ""
         end)
        |> Enum.join("\n")
      graph =
        graph()
        |> Graph.modify(:chat_log, &text(&1, "Chat Log\n\n" <> text, text_align: :center))
        |> Graph.modify(:text_id, &text_field(&1, "", focus: not focus))

      scene =
        scene
        |> assign(log: queue, chat: "", focus: not focus)
        |> push_graph(graph)

      {:noreply, scene}
    else
      {:noreply, scene}
    end
  end

  # 텍스트 변경 시 chat 값 업데이트
  def handle_event({:value_changed, :text_id, new_value}, _context, scene) do
    {:noreply, assign(scene, chat: new_value)}
  end

  def handle_input(_event, _context, scene) do
    {:noreply, scene}
  end

  def connect(pid) do
    case Socket.TCP.connect("127.0.0.1", 1337, packet: :line) do
      {:ok, client} ->
        spawn_link(fn -> client |> handle_recv(pid) end)
        {client}

      {:error, reason} ->
        IO.puts("[!] Failed to connect: #{inspect(reason)}")
        {:error}
    end
  end

  defp handle_recv(client, pid) do
    case client |> Socket.Stream.recv() do
      {:ok, message} when is_bitstring(message) ->
        message = message |> String.trim_trailing()
        send(pid, {:socket_msg, message})
        handle_recv(client, pid)

      {:ok, nil} ->
        IO.puts("[!] Received nil (Server Disconnected).")
        :ok

      {:error, :closed} ->
        IO.puts("[!] Connection closed by server.")
        :ok

      {:error, reason} ->
        IO.puts("[!] Receive error: #{inspect(reason)}")
        :error

      a ->
        IO.puts("[!] Unknown response: #{inspect(a)}")
        :ok
    end
  end

  def handle_info({:socket_msg, msg}, scene) do
    parsed = parse(msg)
    log = :queue.in(parsed, scene.assigns.log)

      list = :queue.to_list(log)
      text = list |> Enum.map(fn
        {sender, message} when sender != self() -> "#{sender}: #{message}"
        {sender, message} when sender == self() -> "me: #{message}"
        _ -> ""
         end)
        |> Enum.join("\n")
      graph =
        graph()
        |> Graph.modify(:chat_log, &text(&1, "Chat Log\n\n" <> text, text_align: :center))

    {:noreply, scene |> assign(log: log) |> push_graph(graph)}
  end

  def parse("{ " <> _ = msg), do: parse(String.trim(msg))

  def parse("{" <> msg) do
    msg
    |> String.trim_trailing("}")
    |> String.split(",", parts: 2)
    |> case do
      [sender, data] ->
        {sender, data}

      _ ->
        {:error, :invalid_format}
    end
  end
end
