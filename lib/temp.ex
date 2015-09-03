defmodule Temp do
  def path(affixes \\ %{}) do
    generate_name(affixes, "")
  end

  def mkdir(affixes \\ %{}) do
    case prefix do
      {:ok, path} ->
        dir_path = Path.join(path, generate_name(affixes, "d-"))
        case File.mkdir dir_path do
          :ok -> dir_path
          err -> err
        end
      err -> err
    end
  end

  defp prefix do
    case System.tmp_dir do
      nil -> {:error, "no tmp_dir readable"}
      path -> {:ok, path}
    end
  end

  defp generate_name(affixes, default_prefix) do
    affixes = parse_affixes(affixes, default_prefix)
    [affixes[:prefix],
     "-",
     timestamp,
     "-",
     :os.getpid,
     "-",
     random_string,
     affixes[:suffix]
    ] |> Enum.join
  end

  defp parse_affixes(affixes, _) when is_bitstring(affixes) do
    %{prefix: affixes, suffix: ""}
  end
  defp parse_affixes(affixes, default_prefix) when is_map(affixes) do
    %{prefix: affixes[:prefix] || default_prefix, suffix: affixes[:suffix] || ""}
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
