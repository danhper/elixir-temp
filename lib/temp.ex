defmodule Temp do
  @type options :: nil | Path.t() | map

  @doc """
  Returns `:ok` when the tracking server used to track temporary files started properly.
  """

  @pdict_key :"$__temp_tracker__"

  @spec track :: Agent.on_start()
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
  Same as `track/0`, but raises an exception on failure. Otherwise, returns `:ok`
  """
  @spec track! :: pid | no_return
  def track!() do
    case track() do
      {:ok, pid} -> pid
      {:error, err} -> raise Temp.Error, message: err
    end
  end

  @doc """
  Return the paths currently tracked.
  """
  @spec tracked :: Set.t()
  def tracked(tracker \\ get_tracker!()) do
    GenServer.call(tracker, :tracked)
  end

  @doc """
  Cleans up the temporary files tracked.
  """
  @spec cleanup(pid, Keyword.t()) :: [Path.t()]
  def cleanup(tracker \\ get_tracker!(), opts \\ []) do
    GenServer.call(tracker, :cleanup, opts[:timeout] || :infinity)
  end

  @doc """
  Returns a `{:ok, path}` where `path` is a path that can be used freely in the
  system temporary directory, or `{:error, reason}` if it fails to get the
  system temporary directory.

  This path is not tracked, so any file created will need manually removing, or
  use `track_file/1` to have it removed automatically.

  ## Options

  The following options can be used to customize the generated path

    * `:prefix` - prepends the given prefix to the path

    * `:suffix` - appends the given suffix to the path,
      this is useful to generate a file with a particular extension

    * `:basedir` - places the generated file in the designated base directory
      instead of the system temporary directory
  """
  @spec path(options) :: {:ok, Path.t()} | {:error, String.t()}
  def path(options \\ nil) do
    case generate_name(options, "f") do
      {:ok, path, _} -> {:ok, path}
      err -> err
    end
  end

  @doc """
  Same as `path/1`, but raises an exception on failure. Otherwise, returns a temporary path.
  """
  @spec path!(options) :: Path.t() | no_return
  def path!(options \\ nil) do
    case path(options) do
      {:ok, path} -> path
      {:error, err} -> raise Temp.Error, message: err
    end
  end

  @doc """
  Returns `{:ok, fd, file_path}` if no callback is passed, or `{:ok, file_path}`
  if callback is passed, where `fd` is the file descriptor of a temporary file
  and `file_path` is the path of the temporary file.
  When no callback is passed, the file descriptor should be closed.
  Returns `{:error, reason}` if a failure occurs.

  The resulting file is automatically tracked if tracking is enabled.

  ## Options

  See `path/1`.
  """
  @spec open(options, nil | (File.io_device() -> any)) ::
          {:ok, Path.t()} | {:ok, File.io_device(), Path.t()} | {:error, any}
  def open(options \\ nil, func \\ nil) do
    case generate_name(options, "f") do
      {:ok, path, options} ->
        options = Map.put(options, :mode, options[:mode] || [:read, :write])

        ret =
          if func do
            File.open(path, options[:mode], func)
          else
            File.open(path, options[:mode])
          end

        case ret do
          {:ok, res} ->
            if tracker = get_tracker(), do: register_path(tracker, path)
            if func, do: {:ok, path}, else: {:ok, res, path}

          err ->
            err
        end

      err ->
        err
    end
  end

  @doc """
  Add a file to the tracker, so that it will be removed automatically or on Temp.cleanup.
  """
  @spec track_file(any) :: {:error, :tracker_not_found} | {:ok, Path.t()}
  def track_file(path, tracker \\ get_tracker()) do
    case is_nil(tracker) do
      true -> {:error, :tracker_not_found}
      false -> {:ok, register_path(tracker, path)}
    end
  end

  @doc """
  Same as `open/1`, but raises an exception on failure.
  """
  @spec open!(options, pid | nil) :: Path.t() | {File.io_device(), Path.t()} | no_return
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

  The directory is automatically tracked if tracking is enabled.

  ## Options

  See `path/1`.
  """
  @spec mkdir(options) :: {:ok, Path.t()} | {:error, any}
  def mkdir(options \\ %{}) do
    case generate_name(options, "d") do
      {:ok, path, _} ->
        case File.mkdir(path) do
          :ok ->
            if tracker = get_tracker(), do: register_path(tracker, path)
            {:ok, path}

          err ->
            err
        end

      err ->
        err
    end
  end

  @doc """
  Same as `mkdir/1`, but raises an exception on failure. Otherwise, returns
  a temporary directory path.
  """
  @spec mkdir!(options) :: Path.t() | no_return
  def mkdir!(options \\ %{}) do
    case mkdir(options) do
      {:ok, path} ->
        if tracker = get_tracker(), do: register_path(tracker, path)
        path

      {:error, err} ->
        raise Temp.Error, message: err
    end
  end

  @doc """
  Removes all passed paths from the tracker for the current processes,
  and gives them to the tracker at heir_pid.
  Returns `:ok` if successful.
  Returns `{:error, reason}` if a failure occurs.
  """
  @spec handoff(Path.t() | [Path.t()], pid()) :: :ok | {:error, String.t()}
  def handoff(paths, heir_pid, tracker \\ get_tracker()) do
    case tracker do
      nil ->
        {:error, "no tracker"}

      tracker_pid ->
        if Process.alive?(heir_pid) do
          paths =
            if !is_list(paths) do
              [paths]
            else
              paths
            end

          GenServer.call(tracker_pid, {:handoff, paths, heir_pid})
        else
          {:error, "dead heir pid"}
        end
    end
  end

  @doc """
  Same as `handoff/3`, but raises an exception on failure. Otherwise, returns `:ok`.
  """
  @spec handoff!(Path.t() | [Path.t()], pid()) :: :ok | no_return()
  def handoff!(paths, heir_pid, tracker \\ get_tracker()) do
    case handoff(paths, heir_pid, tracker) do
      {:error, reason} -> raise Temp.Error, message: reason
      :ok -> :ok
    end
  end

  @spec generate_name(options, Path.t()) ::
          {:ok, Path.t(), map | Keyword.t()} | {:error, String.t()}
  defp generate_name(options, default_prefix)

  defp generate_name(options, default_prefix) when is_list(options) do
    generate_name(Enum.into(options, %{}), default_prefix)
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

      err ->
        err
    end
  end

  defp add_suffix(parts, suffix)
  defp add_suffix(parts, nil), do: parts
  defp add_suffix(parts, "." <> _suffix = suffix), do: parts ++ [suffix]
  defp add_suffix(parts, suffix), do: parts ++ ["-", suffix]

  defp prefix(%{basedir: dir}), do: {:ok, dir}

  defp prefix(_) do
    case System.tmp_dir() do
      nil -> {:error, "no tmp_dir readable"}
      path -> {:ok, path}
    end
  end

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
    {ms, s, _} = :os.timestamp()
    Integer.to_string(ms * 1_000_000 + s)
  end

  defp random_string do
    Integer.to_string(rand_uniform(0x100000000), 36) |> String.downcase()
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
