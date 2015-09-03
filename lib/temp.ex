defmodule Temp do
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

  def open!(options \\ nil) do
    case open(options) do
      {:ok, res, path} -> {res, path}
      {:error, err} -> raise Temp.Error, message: err
    end
  end

  def open!(options, func) do
    case open(options, func) do
      {:ok, res} -> res
      {:error, err} -> raise Temp.Error, message: err
    end
  end

  def open(options \\ nil) do
    open_file(options, nil)
  end

  def open(options, func) do
    case open_file(options, func) do
      {:ok, _, path} -> {:ok, path}
      err -> err
    end
  end

  defp open_file(options, func) do
    case generate_name(options, "f") do
      {:ok, path, options} ->
        unless options[:mode], do: options = Dict.put(options, :mode, [:read, :write])
        ret = if func do
          File.open(path, options[:mode], func)
        else
          File.open(path, options[:mode])
        end
        case ret do
          {:ok, res} -> {:ok, res, path}
          err -> err
        end
      err -> err
    end
  end

  def mkdir!(options \\ %{}) do
    case mkdir(options) do
      {:ok, path} -> path
      {:error, err} -> raise Temp.Error, message: err
    end
  end

  def mkdir(options \\ %{}) do
    case generate_name(options, "d") do
      {:ok, path, _} ->
        case File.mkdir path do
          :ok -> {:ok, path}
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

  defp timestamp do
    {ms, s, _} = :os.timestamp
    Integer.to_string(ms * 1_000_000 + s)
  end

  defp random_string do
    Integer.to_string(:random.uniform(0x100000000), 36) |> String.downcase
  end
end
