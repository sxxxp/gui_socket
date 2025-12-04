defmodule Socket3.Tracker do
  use Agent

  def start_link do
    Agent.start_link(fn -> {0, %{}} end, name: __MODULE__)
  end

  def get_count do
    Agent.get(__MODULE__, fn {c, _map} -> c end)
  end

  def get_clients do
    Agent.get(__MODULE__, fn {_c, map} -> map |> Map.values() end)
  end

  def get_clients(pid) do
    Agent.get(__MODULE__, fn {_c, map} ->
      Map.get(map, pid)
    end)
  end

  def add_client(pid, client) when is_pid(pid) and is_port(client) do
    Agent.update(__MODULE__, fn {c, map} ->
      case Map.put_new(map, pid, client) do
        ^map -> {c, map}
        new_map -> {c + 1, new_map}
      end
    end)
  end

  def add_client(_pid, _client) do
    {:error, :invalid_arguments}
  end

  def delete_client(pid) when is_pid(pid) do
    Agent.update(__MODULE__, fn {c, map} ->
      case Map.delete(map, pid) do
        ^map -> {c, map}
        new_map -> {c - 1, new_map}
      end
    end)
  end

  def delete_client(client) when is_port(client) do
    Agent.update(__MODULE__, fn {c, map} ->
      case Enum.find(map, fn {_pid, port} -> port == client end) do
        nil ->
          {c, map}

        {pid, _port} ->
          new_map = Map.delete(map, pid)
          {c - 1, new_map}
      end
    end)
  end

  def delete_client(pid, client) when is_pid(pid) and is_port(client) do
    delete_client(pid)
  end

  def delete_client(_pid, _client) do
    {:error, :invalid_arguments}
  end
end
