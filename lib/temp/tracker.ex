defmodule Temp.Tracker do
  use GenServer
  @type state :: MapSet.t() | HashSet.t()

  if :application.get_key(:elixir, :vsn) |> elem(1) |> to_string() |> Version.match?("~> 1.1") do
    defp set(), do: MapSet.new()
    defp set(list), do: MapSet.new(list)
    defdelegate union(set1, set2), to: MapSet
    defdelegate put(set, value), to: MapSet
    defdelegate difference(set1, set2), to: MapSet
    defdelegate intersection(set1, set2), to: MapSet
  else
    defp set(), do: HashSet.new()

    defp set(list) do
      set_helper(list, set())
    end

    defp set_helper([], cur_set), do: cur_set

    defp set_helper([head | tail], cur_set) do
      set_helper(tail, put(cur_set, head))
    end

    defdelegate union(set1, set2), to: HashSet
    defdelegate put(set, value), to: HashSet
    defdelegate difference(set1, set2), to: HashSet
    defdelegate intersection(set1, set2), to: HashSet
  end

  @spec start_link(pid()) :: GenServer.on_start()
  def start_link(tracked_pid) do
    GenServer.start_link(__MODULE__, tracked_pid)
  end

  @spec init(any()) :: {:ok, state()}
  def init(_) do
    Process.flag(:trap_exit, true)
    {:ok, set()}
  end

  def handle_call({:add, item}, _from, state) do
    {:reply, item, put(state, item)}
  end

  def handle_call({:receive, passed_over_set}, _from, state) do
    {:reply, :ok, union(passed_over_set, state)}
  end

  def handle_call(:tracked, _from, state) do
    {:reply, state, state}
  end

  def handle_call(:cleanup, _from, state) do
    {removed, failed} = cleanup(state)
    {:reply, removed, Enum.into(failed, set())}
  end

  def handle_call({:handoff, paths, heir_pid}, _from, state) do
    paths_set = set(paths)
    new_state = difference(state, paths_set)
    passed_over_set = intersection(state, paths_set)
    GenServer.call(heir_pid, {:receive, passed_over_set})
    {:reply, :ok, new_state}
  end

  def terminate(_reason, state) do
    cleanup(state)
    :ok
  end

  defp cleanup(state) do
    {removed, failed} =
      state
      |> Enum.reduce({[], []}, fn path, {removed, failed} ->
        case File.rm_rf(path) do
          {:ok, _} -> {[path | removed], failed}
          _ -> {removed, [path | failed]}
        end
      end)

    {:lists.reverse(removed), :lists.reverse(failed)}
  end
end
