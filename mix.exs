defmodule Temp.Mixfile do
  use Mix.Project

  def project do
    [app: :temp,
     version: "0.1.0",
     elixir: "~> 1.0",
     package: package,
     description: description,
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps]
  end

  def application do
    [applications: [:logger]]
  end

  defp deps do
    []
  end

  defp description do
    "An Elixir module to easily create and use temporary files and directories."
  end

  defp package do
  [
    files: ["lib", "mix.exs", "README.md", "LICENSE"],
    contributors: ["Daniel Perez"],
    licenses: ["MIT"],
    links: %{"GitHub" => "https://github.com/tuvistavie/elixir-temp"}
  ]
 end
end
