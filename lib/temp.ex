defmodule Temp do
  @type options :: nil | Path.t | map

  @doc """
  Returns `:ok` when the tracking server used to track temporary files started properly.
  """

  @pdict_key :"$__temp_tracker__"

  @spec track :: Agent.on_start
  def track() do
    case Process.get(@pdict_key) do
      nil ->
        start_tracker()
      v ->
        {:ok, v}
    end
  end

  defp start_tracker() do
    case GenServer.start_link(Temp.Tracker, nil, []) do
      {:ok, pid} ->
        Process.put(@pdict_key, pid)
        {:ok, pid}
      err ->
        err
    end
  end

  @doc """
  Same as `track/1`, but raises an exception on failure. Otherwise, returns `:ok`
  """
  @spec track! :: pid
  def track!() do
    case track() do
      {:ok, pid} -> pid
      err        -> raise Temp.Error, message: err
    end
  end

  @doc """
  Return the paths currently tracked.
  """
  @spec tracked :: Set.t
  def tracked(tracker \\ get_tracker!()) do
    GenServer.call(tracker, :tracked)
  end


  @doc """
  Cleans up the temporary files tracked.
  """
  @spec cleanup(pid, Keyword.t) :: :ok | {:error, any}
  def cleanup(tracker \\ get_tracker!(), opts \\ []) do
    GenServer.call(tracker, :cleanup, opts[:timeout] || :infinity)
  end

  @doc """
  Returns a `{:ok, path}` where `path` is a path that can be used freely in the
  system temporary directory, or `{:error, reason}` if it fails to get the
  system temporary directory.

  ## Options

  The following options can be used to customize the generated path

    * `:prefix` - prepends the given prefix to the path

    * `:suffix` - appends the given suffix to the path,
      this is useful to generate a file with a particular extension
  """
  @spec path(options) :: {:ok, Path.t} | {:error, String.t}
  def path(options \\ nil) do
    case generate_name(options, "f") do
      {:ok, path, _} -> {:ok, path}
      err -> err
    end
  end

  @doc """
  Same as `path/1`, but raises an exception on failure. Otherwise, returns a temporary path.
  """
  @spec path!(options) :: Path.t
  def path!(options \\ nil) do
    case path(options) do
      {:ok, path} -> path
      err -> err
    end
  end

  @doc """
  Returns `{:ok, fd, file_path}` if no callback is passed, or `{:ok, file_path}`
  if callback is passed, where `fd` is the file descriptor of a temporary file
  and `file_path` is the path of the temporary file.
  When no callback is passed, the file descriptor should be closed.
  Returns `{:error, reason}` if a failure occurs.

  ## Options

  See `path/1`.
  """
  @spec open(options, nil | (File.io_device -> any)) :: {:ok, File.io_device, Path.t} | {:error, any}
  def open(options \\ nil, func \\ nil) do
    case generate_name(options, "f") do
      {:ok, path, options} ->
        options = Map.put(options, :mode, options[:mode] || [:read, :write])
        ret = if func do
          File.open(path, options[:mode], func)
        else
          File.open(path, options[:mode])
        end
        case ret do
          {:ok, res} ->
            if tracker = get_tracker(), do: register_path(tracker, path)
            if func, do: {:ok, path}, else: {:ok, res, path}
          err -> err
        end
      err -> err
    end
  end

  @doc """
  Same as `open/1`, but raises an exception on failure.
  """
  @spec open!(options, pid | nil) :: {File.io_device, Path.t}
  def open!(options \\ nil, func \\ nil) do
    case open(options, func) do
      {:ok, res, path} -> {res, path}
      {:ok, path} -> path
      {:error, err} -> raise Temp.Error, message: err
    end
  end


  @doc """
  Returns `{:ok, dir_path}` where `dir_path` is the path is the path of the
  created temporary directory.
  Returns `{:error, reason}` if a failure occurs.

  ## Options

  See `path/1`.
  """
  @spec mkdir(options) :: {:ok, Path.t} | {:error, any}
  def mkdir(options \\ %{}) do
    case generate_name(options, "d") do
      {:ok, path, _} ->
        case File.mkdir path do
          :ok ->
            if tracker = get_tracker(), do: register_path(tracker, path)
            {:ok, path}
          err -> err
        end
      err -> err
    end
  end

  @doc """
  Same as `mkdir/1`, but raises an exception on failure. Otherwise, returns
  a temporary directory path.
  """
  @spec mkdir!(options) :: Path.t
  def mkdir!(options \\ %{}) do
    case mkdir(options) do
      {:ok, path} ->
        if tracker = get_tracker(), do: register_path(tracker, path)
        path
      {:error, err} -> raise Temp.Error, message: err
    end
  end

  @spec generate_name(options, Path.t) :: {:ok, Path.t, map | Keyword.t} | {:error, String.t}
  defp generate_name(options, default_prefix)
  defp generate_name(options, default_prefix) when is_list(options) do
    generate_name(Enum.into(options,%{}), default_prefix)
  end
  defp generate_name(options, default_prefix) do
    case prefix(options) do
      {:ok, path} ->
        affixes = parse_affixes(options, default_prefix)
        parts = [timestamp(), "-", :os.getpid(), "-", random_string()]
        parts =
          if affixes[:prefix] do
            [affixes[:prefix], "-"] ++ parts
          else
            parts
          end
        parts = add_suffix(parts, affixes[:suffix])
        name = Path.join(path, Enum.join(parts))
        {:ok, name, affixes}
      err -> err
    end
  end


  @spec add_suffix([String.t], nil | String.t) :: [String.t]
  defp add_suffix(parts, suffix)
  defp add_suffix(parts, nil), do: parts
  defp add_suffix(parts, ("." <> _suffix) = suffix), do: parts ++ [suffix]
  defp add_suffix(parts, suffix), do: parts ++ ["-", suffix]

  @spec prefix(nil | map) :: {:ok, Path.t} | {:error, String.t}
  defp prefix(%{basedir: dir}), do: {:ok, dir}
  defp prefix(_) do
    case System.tmp_dir do
      nil -> {:error, "no tmp_dir readable"}
      path -> {:ok, path}
    end
  end

  @spec parse_affixes(options, Path.t) :: map
  defp parse_affixes(nil, default_prefix), do: %{prefix: default_prefix}
  defp parse_affixes(affixes, _) when is_bitstring(affixes), do: %{prefix: affixes, suffix: nil}
  defp parse_affixes(affixes, default_prefix) when is_map(affixes) do
    affixes
    |> Map.put(:prefix, affixes[:prefix] || default_prefix)
    |> Map.put(:suffix, affixes[:suffix] || nil)
  end
  defp parse_affixes(_, default_prefix) do
    %{prefix: default_prefix, suffix: nil}
  end

  defp get_tracker do
    Process.get(@pdict_key)
  end

  defp get_tracker!() do
    case get_tracker() do
      nil ->
        raise Temp.Error, message: "temp tracker not started"
      pid ->
        pid
    end
  end

  defp register_path(tracker, path) do
    GenServer.call(tracker, {:add, path})
  end

  defp timestamp do
    {ms, s, _} = :os.timestamp
    Integer.to_string(ms * 1_000_000 + s)
  end

  defp random_string do
    Integer.to_string(rand_uniform(0x100000000), 36) |> String.downcase
  end

  if :erlang.system_info(:otp_release) >= '18' do
    defp rand_uniform(num) do
      :rand.uniform(num)
    end
  else
    defp rand_uniform(num) do
      :random.uniform(num)
    end
  end
end
