# elixir-temp [![Build Status](https://travis-ci.org/tuvistavie/elixir-temp.svg?branch=master)](https://travis-ci.org/tuvistavie/elixir-temp)

An Elixir module to easily create and use temporary files and directories.
The module is inspired by [node-temp](https://github.com/bruce/node-temp).

## Installation

Add the dependency to your `mix.exs` deps:

```elixir
defp deps do
  [{:temp, "~> 0.4"}]
end
```

## Usage

### Getting a temporary path

```elixir
# just get a path
{:ok, tmp_path} = Temp.path
# with a prefix
{:ok, tmp_path} = Temp.path "my-prefix"
# with prefix and suffix
{:ok, tmp_path} = Temp.path %{prefix: "my-prefix", suffix: "my-suffix"}
# in a non-default tmp_dir
{:ok, tmp_path} = Temp.path %{prefix: "my-prefix", suffix: "my-suffix", basedir: "/my-tmp"}
# error on fail
tmp_path = Temp.path!
```

### Using a temporary directory

Note that you can use all the options available for `Temp.path` as the first argument.

```elixir
# tmp dir
{:ok, dir_path} = Temp.mkdir "my-dir"
IO.puts dir_path
File.write Path.join(dir_path, "file_in_my_dir"), "some content"
# remove when done
File.rm_rf dir_path
```

You can use the `Temp.mkdir!` if you prefer to have an error on failure.

### Using a temporary file

Note that you can use all the options available for `Temp.path` as the first argument.

```elixir
# tmp file
{:ok, fd, file_path} = Temp.open "my-file"
IO.puts file_path
IO.write fd, "some content"
File.close fd
# remove when done
File.rm file_path
```

You can also pass a function to `open` and use the file descriptor in it. In this case, the file will be closed automatically.

```elixir
# tmp file
{:ok, file_path} = Temp.open "my-file", &IO.write(&1, "some content")
IO.puts file_path
IO.puts File.read!(file_path)
# remove when done
File.rm file_path
```

### Tracking temporary files

By default, you have to cleanup the files by yourself, however, you can tell
`Temp` to track the temporary files.
You just need to call `Temp.track` (or the bang version `Temp.track!`) and you are done.
Temporary files will be cleaned up automatically when the process exits.
You can also call `Temp.cleanup` if you want to clean them before the process exits.
Here is an example of how to use it.

```elixir
Temp.track!

dir_path = Temp.mkdir! "my-dir"
File.write Path.join(dir_path, "file_in_my_dir"), "some content"

file_path = Temp.open! "my-file", &IO.write(&1, "some content")
IO.puts file_path

IO.puts inspect(Temp.tracked)

# cleanup
Temp.cleanup

dir_path = Temp.mkdir
# this will be cleaned up on exit
```
