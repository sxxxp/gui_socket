defmodule Gui.Scene.Home do
  use Scenic.Scene
  require Logger

  alias Scenic.Graph

  import Scenic.Primitives
  # import Scenic.Components

  @note """
  (this is a demo scene - touch or click anywhere)
  """

  @text_size 24
  @host "127.0.0.1"
  @port 1337
  # ============================================================================
  # setup

  # --------------------------------------------------------
  def init(scene, _param, _opts) do
    # get the width and height of the viewport. This is to demonstrate creating
    # a transparent full-screen rectangle to catch user input
    {width, height} = scene.viewport.size

    # show the version of scenic and the glfw driver

    info = "hi! welcome to Socket Server!
      IP address: #{@host}
      Port: #{@port}"

    graph =
      Graph.build(font: :roboto, font_size: @text_size)
      |> add_specs_to_graph([
        text_spec(info, translate: {20, 20}),
        text_spec(@note, translate: {20, 120}),
        rect_spec({width, height})
      ])

    scene = push_graph(scene, graph)

    {:ok, scene}
  end

  def handle_input(event, _context, scene) do
    Logger.info("Received event: #{inspect(event)}")
    {:noreply, scene}
  end
end
