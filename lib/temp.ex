defmodule Temp do
  def track! do
    case track do
      {:ok, tracker} -> tracker
      err -> raise Temp.Error, message: err
    end
  end

  def track do
    Agent.start_link(fn -> HashSet.new end)
  end

  def cleanup(tracker) do
    result = Agent.get tracker, fn paths ->
      Enum.each(paths, &File.rm_rf!(&1))
    end
    case result do
      {:ok, _} -> :ok
      err -> err
    end
  end

  def path!(options \\ nil) do
    case path(options) do
      {:ok, path} -> path
      err -> err
    end
  end

  def path(options \\ nil) do
    case generate_name(options, "f") do
      {:ok, path, _} -> {:ok, path}
      err -> err
    end
  end

  def open!(options \\ nil, func \\ nil) do
    case open(options, func) do
      {:ok, res, path} -> {res, path}
      {:error, err} -> raise Temp.Error, message: err
    end
  end

  def open(options \\ nil, func \\ nil, tracker \\ nil) do
    case generate_name(options, "f") do
      {:ok, path, options} ->
        options = Dict.put(options, :mode, options[:mode] || [:read, :write])
        ret = if func do
          File.open(path, options[:mode], func)
        else
          File.open(path, options[:mode])
        end
        case ret do
          {:ok, res} ->
            if tracker, do: register_path(tracker, path)
            if func, do: {:ok, path}, else: {:ok, res, path}
          err -> err
        end
      err -> err
    end
  end

  def mkdir!(options \\ %{}, tracker \\ nil) do
    case mkdir(options) do
      {:ok, path} ->
        if tracker, do: register_path(tracker, path)
        path
      {:error, err} -> raise Temp.Error, message: err
    end
  end

  def mkdir(options \\ %{}, tracker \\ nil) do
    case generate_name(options, "d") do
      {:ok, path, _} ->
        case File.mkdir path do
          :ok ->
            if tracker, do: register_path(tracker, path)
            {:ok, path}
          err -> err
        end
      err -> err
    end
  end

  defp generate_name(options, default_prefix) do
    case prefix(options) do
      {:ok, path} ->
        affixes = parse_affixes(options, default_prefix)
        name = Path.join(path, [
         affixes[:prefix],
         "-",
         timestamp,
         "-",
         :os.getpid,
         "-",
         random_string,
         affixes[:suffix]
        ] |> Enum.join)
        {:ok, name, affixes}
      err -> err
    end
  end

  defp prefix(%{basedir: dir}), do: {:ok, dir}
  defp prefix(_) do
    case System.tmp_dir do
      nil -> {:error, "no tmp_dir readable"}
      path -> {:ok, path}
    end
  end

  defp parse_affixes(nil, default_prefix), do: %{prefix: default_prefix}
  defp parse_affixes(affixes, _) when is_bitstring(affixes), do: %{prefix: affixes, suffix: ""}
  defp parse_affixes(affixes, default_prefix) when is_map(affixes) do
    affixes
    |> Dict.put(:prefix, affixes[:prefix] || default_prefix)
    |> Dict.put(:suffix, affixes[:suffix] || "")
  end
  defp parse_affixes(_, default_prefix) do
    %{prefix: default_prefix, suffix: ""}
  end

  defp register_path(tracker, path) do
    Agent.update(tracker, &Set.put(&1, path))
  end

  defp timestamp do
    {ms, s, _} = :os.timestamp
    Integer.to_string(ms * 1_000_000 + s)
  end

  defp random_string do
    Integer.to_string(:random.uniform(0x100000000), 36) |> String.downcase
  end
end
