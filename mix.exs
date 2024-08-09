defmodule Temp.Mixfile do
  use Mix.Project

  @source_url "https://github.com/tuvistavie/elixir-temp"
  @version "0.4.8"

  def project do
    [
      app: :temp,
      version: @version,
      elixir: "~> 1.9",
      name: "temp",
      source_url: @source_url,
      homepage_url: @source_url,
      package: package(),
      description: description(),
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: [source_ref: "#{@version}", extras: ["README.md"], main: "readme"]
    ]
  end

  def application do
    [extra_applications: [:logger]]
  end

  defp deps() do
    [
      {:earmark, "~> 1.0", only: :dev},
      {:ex_doc, "~> 0.19", only: :dev}
    ]
  end

  defp description do
    "An Elixir module to easily create and use temporary files and directories."
  end

  defp package do
    [
      files: ["lib", "mix.exs", "README.md", "LICENSE"],
      maintainers: ["Daniel Perez"],
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url}
    ]
  end
end
