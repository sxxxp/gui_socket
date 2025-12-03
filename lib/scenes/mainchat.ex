defmodule Gui.Scene.MainChat do
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
           rect_spec({800, 1080})
         ])
         |> group(
           fn graph ->
             graph
             |> text("" <> inspect(:queue.to_list(:queue.new())), id: :chat_log)
           end,
           translate: {20, 100}
         )
         |> text_field("", hint: "Enter Message", id: :text_id, focus: true, translate: {20, 240})
         |> rect({50, 30},
           fill: :light_gray,
           id: :submit_button,
           input: :cursor_button,
           translate: {330, 240}
         )

  # ============================================================================
  # setup
  defp graph(), do: @graph
  # --------------------------------------------------------

  def init(scene, _param, _opts) do
    # get the width and height of the viewport. This is to demonstrate creating
    # a transparent full-screen rectangle to catch user input
    # {width, height} = scene.viewport.size

    # show the version of scenic and the glfw driver

    scene =
      scene
      |> assign(log: :queue.new(), chat: "", focus: true)
      |> push_graph(graph())

    {:ok, scene}
  end

  def handle_input(
        {:cursor_button, {:btn_left, 1, _, _}},
        :submit_button,
        %{assigns: %{chat: chat, log: log, focus: focus}} = scene
      ) do
    if chat != "" do
      queue = :queue.in(%{self() => chat}, log)
      Logger.info(:queue.to_list(queue))

      graph =
        graph()
        |> Graph.modify(:chat_log, &text(&1, inspect(:queue.to_list(queue))))
        |> Graph.modify(:text_id, &text_field(&1, "", focus: not focus))

      scene = scene |> assign(log: queue, chat: "", focus: not focus) |> push_graph(graph)
      {:noreply, scene}
    else
      {:noreply, scene}
    end
  end

  def handle_input(event, :text_id, scene) do
    {:noreply, scene}
  end

  def handle_input(event, _context, scene) do
    {:noreply, scene}
  end

  def handle_event(
        {:value_changed, :text_id, new_value},
        _context,
        %{assigns: %{chat: chat}} = scene
      ) do
    chat = new_value
    scene = scene |> assign(chat: chat)
    {:noreply, scene}
  end
end
