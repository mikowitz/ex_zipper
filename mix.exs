defmodule ExZipper.Mixfile do
  use Mix.Project

  def project do
    [
      app: :ex_zipper,
      name: "ExZipper",
      version: "0.1.3",
      elixir: ">= 1.7.0",
      deps: deps(),
      build_embedded: Mix.env() == :prod,
      description: "Huet's zippers in Elixir",
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ],
      package: package()
    ]
  end

  def application do
    [
      # built-in apps that need starting
      extra_applications: [
        :logger
      ]
    ]
  end

  defp deps do
    [
      {:credo, github: "rrrene/credo", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.10", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.21", only: [:dev, :test], runtime: false},
      {:mix_test_watch, "~> 0.5.0", only: [:dev, :test], runtime: false},
    ]
  end

  defp package do
    [
      name: "ex_zipper",
      licenses: ["UNLICENSE"],
      files: ~w(lib mix.exs README* UNLICENSE),
      maintainers: [
        "Michael Berkowitz <michael.berkowitz@gmail.com>"
      ],
      links: %{
        "GitHub" => "https://github.com/mikowitz/ex_zipper.git"
      }
    ]
  end
end
