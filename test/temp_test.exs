defmodule TempTest do
  use ExUnit.Case

  test :path do
    {:ok, path} = Temp.path()
    assert File.exists?(Path.dirname(path))
    assert String.starts_with?(Path.basename(path), "f-")
    refute String.ends_with?(Path.basename(path), "-")

    path = Temp.path!()
    assert File.exists?(Path.dirname(path))
    assert path != Temp.path!()

    path = Temp.path!(basedir: "foo")
    assert Path.dirname(path) == "foo"

    path = Temp.path!(basedir: "bar", prefix: "my-prefix")
    assert Path.dirname(path) == "bar"
    assert String.starts_with?(Path.basename(path), "my-prefix-")

    path = Temp.path!(basedir: "other", prefix: "my-prefix", suffix: "my-suffix")
    assert Path.dirname(path) == "other"
    assert String.starts_with?(Path.basename(path), "my-prefix-")
    assert String.ends_with?(Path.basename(path), "-my-suffix")

    path = Temp.path!(suffix: ".txt")
    assert String.ends_with?(path, ".txt")
    refute String.ends_with?(path, "-.txt")
  end

  test :open do
    {:ok, file, path} = Temp.open()
    assert File.exists?(path)
    assert String.starts_with?(Path.basename(path), "f-")
    refute String.ends_with?(Path.basename(path), "-")
    IO.write(file, "foobar")
    File.close(file)
    assert File.read!(path) == "foobar"
    File.rm!(path)

    {:ok, path} = Temp.open("bar", fn f -> IO.write(f, "foobar") end)
    assert File.exists?(path)
    assert File.read!(path) == "foobar"
    File.rm!(path)

    {err, _} = Temp.open(basedir: "/")
    assert err == :error
  end

  test :open! do
    {file, path} = Temp.open!()
    assert File.exists?(path)
    assert String.starts_with?(Path.basename(path), "f-")
    refute String.ends_with?(Path.basename(path), "-")
    IO.write(file, "foobar")
    File.close(file)
    assert File.read!(path) == "foobar"
    File.rm!(path)

    path = Temp.open!("bar", fn f -> IO.write(f, "foobar") end)
    assert File.exists?(path)
    assert File.read!(path) == "foobar"
    File.rm!(path)

    assert_raise Temp.Error, fn ->
      Temp.open!(%{basedir: "/"})
    end
  end

  test :mkdir do
    {:ok, dir} = Temp.mkdir()
    assert File.exists?(dir)
    assert String.starts_with?(Path.basename(dir), "d-")
    refute String.ends_with?(Path.basename(dir), "-")
    File.rmdir!(dir)

    dir = Temp.mkdir!("abc")
    assert File.exists?(dir)
    assert String.starts_with?(Path.basename(dir), "abc")
    File.rmdir!(dir)

    {osfamily, _} = :os.type()

    unless osfamily == :win32 do
      {err, _} = Temp.mkdir(basedir: "/")
      assert err == :error
    end
  end

  test :track do
    assert {:ok, tracker} = Temp.track()
    {:ok, dir} = Temp.mkdir(nil)
    assert File.exists?(dir)

    {:ok, path} = Temp.open("bar", &IO.write(&1, "foobar"))
    assert File.exists?(path)

    assert Enum.count(Temp.tracked()) == 2

    parent = self()

    spawn_link(fn ->
      send(parent, {:count, Temp.tracked(tracker) |> Enum.count()})
    end)

    assert_receive {:count, 2}

    assert Enum.count(Temp.cleanup()) == 2
    refute File.exists?(dir)
    refute File.exists?(path)
    assert Enum.count(Temp.tracked()) == 0

    # check cleanup can be called multiple times safely
    {:ok, dir} = Temp.mkdir(nil)
    assert File.exists?(dir)
    assert Enum.count(Temp.cleanup()) == 1
    refute File.exists?(dir)

    {:ok, dir} = Temp.mkdir(nil)

    spawn_link(fn ->
      send(parent, {:cleaned, Temp.cleanup(tracker) |> Enum.count()})
    end)

    assert_receive {:cleaned, 1}
    refute File.exists?(dir)
  end

  test :track_file do
    assert {:ok, tracker} = Temp.track()

    path_of_tmp_file = "test/tmp_file_created_by_programmer"
    File.write!(path_of_tmp_file, "Make Elixir Gr8 Again")

    assert File.exists?(path_of_tmp_file)

    Temp.track_file(path_of_tmp_file, tracker)

    Temp.cleanup(tracker)

    refute File.exists?(path_of_tmp_file)
  end

  test :handoff do
    Temp.mkdir!()

    heir_pid = Temp.track!()
    assert Temp.tracked() == MapSet.new()

    path_of_tmp_file =
      Task.async(fn ->
        Temp.track!()
        dir = Temp.mkdir!()
        Temp.handoff(dir, heir_pid)
        dir
      end)
      |> Task.await()

    assert Temp.tracked() == Temp.Tracker.set([path_of_tmp_file])
    assert File.exists?(path_of_tmp_file)

    Temp.cleanup()

    Task.start(fn ->
      Temp.track!()
      dir = Temp.mkdir!()
      Temp.handoff(dir, heir_pid)
      1 = 2
    end)

    :timer.sleep(50)
    refute Temp.tracked() == Temp.Tracker.set()
    Temp.cleanup()
  end

  test "automatically cleans up" do
    dir = Temp.mkdir!()
    assert File.exists?(dir)

    normal_end =
      Task.async(fn ->
        Temp.track!()
        Temp.track_file(dir)
        :ok
      end)

    Task.await(normal_end)
    :timer.sleep(50)
    refute File.exists?(dir)
  end

  test "automatically cleans up after crashes" do
    dir = Temp.mkdir!()
    assert File.exists?(dir)

    Task.start(fn ->
      Temp.track!()
      Temp.track_file(dir)
      exit(:kill)
      :ok
    end)

    :timer.sleep(50)
    refute File.exists?(dir)
  end
end
