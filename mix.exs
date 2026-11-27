defmodule ExZipper.MixProject do
  use Mix.Project

  @version "1.0.0"
  @source_url "https://github.com/mikowitz/ex_zipper"

  def project do
    [
      app: :ex_zipper,
      name: "ExZipper",
      version: @version,
      elixir: "~> 1.17",
      deps: deps(),
      description: "Huet's zippers in Elixir",
      source_url: @source_url,
      docs: docs(),
      test_coverage: [tool: ExCoveralls],
      package: package()
    ]
  end

  def application do
    []
  end

  def cli do
    [
      preferred_envs: [
        "test.interactive": :test,
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ]
    ]
  end

  defp deps do
    [
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.18.5", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false},
      {:mix_test_interactive, "~> 6.0", only: [:dev, :test], runtime: false}
    ]
  end

  defp docs do
    [
      main: "readme",
      source_ref: "v#{@version}",
      extras: ["README.md", "CHANGELOG.md"]
    ]
  end

  defp package do
    [
      licenses: ["Unlicense"],
      files: ~w(lib mix.exs README* CHANGELOG* UNLICENSE),
      links: %{
        "GitHub" => @source_url
      }
    ]
  end
end
