defmodule Temp.Tracker do
  use GenServer

  if :application.get_key(:elixir, :vsn) |> elem(1) |> to_string() |> Version.match?("~> 1.1") do
    defp set(), do: MapSet.new
    defdelegate put(set, value), to: MapSet
  else
    defp set(), do: HashMap.new
    defdelegate put(set, value), to: HashSet
  end

  def init(_args) do
    {:ok, %{}}
  end

  def track() do
    GenServer.call(tracker, :track)
  end

  def handle_call(:track, {pid, _tag}, state) do
  end

  def handle_call({:add, item}, {pid, _tag}, state) do
    files = Map.get(state, pid, set())
    {:reply, item, Map.put(pid, put(files, item))}
  end

  def handle_call(:tracked, {pid, _tag}, state) do
    {:reply, Map.get(state, pid, set()), state}
  end

  def handle_call(:cleanup, {pid, _tag}, state) do
    {removed, failed} = cleanup(Map.get(state, pid, set()))
    {:reply, removed, Map.put(state, pid, Enum.into(failed, set()))}
  end

  defp cleanup(files) do
    {removed, failed} =
      files
      |> Enum.reduce({[], []}, fn path, {removed, failed} ->
        case File.rm_rf(path) do
          {:ok, _} -> {[path | removed], failed}
          _ -> {removed, [path | failed]}
        end
      end)
    {:lists.reverse(removed), :lists.reverse(failed)}
  end
end
