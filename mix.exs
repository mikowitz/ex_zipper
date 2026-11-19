defmodule ExZipper.Mixfile do
  use Mix.Project

  def project do
    [
      app: :ex_zipper,
      name: "ExZipper",
      version: "0.2.0",
      elixir: ">= 1.20.0",
      deps: deps(),
      build_embedded: Mix.env() == :prod,
      description: "Huet's zippers in Elixir",
      test_coverage: [tool: ExCoveralls],
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
      {:excoveralls, "~> 0.18.5", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.34", only: [:dev, :test], runtime: false},
      {:mix_test_interactive, "~> 6.0", only: [:dev, :test], runtime: false}
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
