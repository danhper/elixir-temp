defmodule Temp.Mixfile do
  use Mix.Project

  @version "0.4.3"

  def project do
    [app: :temp,
     version: @version,
     elixir: "~> 1.0",
     name: "temp",
     source_url: "http://github.com/tuvistavie/elixir-temp",
     homepage_url: "http://github.com/tuvistavie/elixir-temp",
     package: package(),
     description: description(),
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps(),
     docs: [source_ref: "#{@version}", extras: ["README.md"], main: "readme"]]
  end

  def application do
    [applications: [:logger]]
  end

  defp deps do
    [{:earmark, "~> 1.0", only: :dev},
     {:ex_doc, "~> 0.14", only: :dev}]
  end

  defp description do
    "An Elixir module to easily create and use temporary files and directories."
  end

  defp package do
  [
    files: ["lib", "mix.exs", "README.md", "LICENSE"],
    maintainers: ["Daniel Perez"],
    licenses: ["MIT"],
    links: %{"GitHub" => "https://github.com/tuvistavie/elixir-temp"}
  ]
 end
end
