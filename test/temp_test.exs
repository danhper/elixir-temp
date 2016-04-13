defmodule TempTest do
  use ExUnit.Case

  test :path do
    {:ok, path} = Temp.path
    assert File.exists?(Path.dirname(path))
    assert String.starts_with?(Path.basename(path), "f-")
    assert !String.ends_with?(Path.basename(path), "-")

    path = Temp.path!
    assert File.exists?(Path.dirname(path))
    assert path != Temp.path!

    path = Temp.path! %{basedir: "foo"}
    assert Path.dirname(path) == "foo"

    path = Temp.path! %{basedir: "bar", prefix: "my-prefix"}
    assert Path.dirname(path) == "bar"
    assert String.starts_with?(Path.basename(path), "my-prefix")

    path = Temp.path! %{basedir: "other", prefix: "my-prefix", suffix: "my-suffix"}
    assert Path.dirname(path) == "other"
    assert String.starts_with?(Path.basename(path), "my-prefix")
    assert String.ends_with?(Path.basename(path), "my-suffix")
  end

  test :open do
    {:ok, file, path} = Temp.open
    assert File.exists?(path)
    assert String.starts_with?(Path.basename(path), "f-")
    assert !String.ends_with?(Path.basename(path), "-")
    IO.write file, "foobar"
    File.close(file)
    assert File.read!(path) == "foobar"
    File.rm!(path)

    {:ok, path} = Temp.open "bar", fn f -> IO.write(f, "foobar") end
    assert File.exists?(path)
    assert File.read!(path) == "foobar"
    File.rm!(path)

    {err, _} = Temp.open %{basedir: "/"}
    assert err == :error
  end

  test :open! do
    {file, path} = Temp.open!
    assert File.exists?(path)
    assert String.starts_with?(Path.basename(path), "f-")
    assert !String.ends_with?(Path.basename(path), "-")
    IO.write file, "foobar"
    File.close(file)
    assert File.read!(path) == "foobar"
    File.rm!(path)

    path = Temp.open! "bar", fn f -> IO.write(f, "foobar") end
    assert File.exists?(path)
    assert File.read!(path) == "foobar"
    File.rm!(path)

    assert_raise Temp.Error, fn ->
      Temp.open! %{basedir: "/"}
    end
  end

  test :mkdir do
    {:ok, dir} = Temp.mkdir
    assert File.exists?(dir)
    assert String.starts_with?(Path.basename(dir), "d-")
    assert !String.ends_with?(Path.basename(dir), "-")
    File.rmdir!(dir)

    dir = Temp.mkdir! "abc"
    assert File.exists?(dir)
    assert String.starts_with?(Path.basename(dir), "abc")
    File.rmdir!(dir)

    {osfamily, _} = :os.type
    unless osfamily == :win32 do
      {err, _} = Temp.mkdir %{basedir: "/"}
      assert err == :error
    end
  end

  test :track do
    assert {:ok, tracker} = Temp.track
    {:ok, dir} = Temp.mkdir nil
    assert File.exists?(dir)

    {:ok, path} = Temp.open "bar", &IO.write(&1, "foobar")
    assert File.exists?(path)

    assert Enum.count(Temp.tracked) == 2

    parent = self
    spawn_link fn ->
      send parent, {:count, Temp.tracked(tracker) |> Enum.count}
    end
    assert_receive {:count, 2}

    assert Enum.count(Temp.cleanup) == 2
    assert !File.exists?(dir)
    assert !File.exists?(path)
    assert Enum.count(Temp.tracked) == 0

    # check cleanup can be called multiple times safely
    {:ok, dir} = Temp.mkdir nil
    assert File.exists?(dir)
    assert Enum.count(Temp.cleanup) == 1
    assert !File.exists?(dir)

    {:ok, dir} = Temp.mkdir nil
    spawn_link fn ->
      send parent, {:cleaned, Temp.cleanup(tracker) |> Enum.count}
    end
    assert_receive {:cleaned, 1}
    assert !File.exists?(dir)
  end
end
