defmodule Temp.Tracker do
  use GenServer

  def init(_args) do
    Process.flag(:trap_exit, true)
    {:ok, HashSet.new}
  end

  def handle_call({:add, item}, _from, state) do
    {:reply, item, HashSet.put(state, item)}
  end

  def handle_call(:tracked, _from, state) do
    {:reply, state, state}
  end

  def handle_call(:cleanup, _from, state) do
    {removed, failed} = cleanup(state)
    {:reply, removed, Enum.into(failed, HashSet.new)}
  end

  def terminate(_reason, state) do
    cleanup(state)
    :ok
  end

  defp cleanup(state) do
    Enum.partition state, fn path ->
      case File.rm_rf(path) do
        {:ok, _} -> true
        _ -> false
      end
    end
  end
end
