defmodule ExZipper.Mixfile do
  use Mix.Project

  @name :ex_zipper
  @version "0.1.1"

  @deps [
    {:credo, github: "rrrene/credo", only: [:dev, :test], runtime: false},
    {:mix_test_watch, "~> 0.5.0", only: :dev, runtime: false},
    {:ex_doc, "~> 0.18.1", only: [:dev, :test], runtime: false},
    {:stream_data, "~> 0.3.0"}
  ]

  # ------------------------------------------------------------

  def project do
    in_production = Mix.env() == :prod

    [
      app: @name,
      version: @version,
      elixir: ">= 1.5.0",
      deps: @deps,
      build_embedded: in_production,
      description: "Huet's zippers in Elixir",
      source_url: "https://github.com/mikowitz/ex_zipper.git",
      homepage_url: "https://github.com/mikowitz/ex_zipper.git",
      package: [
        licenses: ["MIT"],
        maintainers: [
          "Michael Berkowitz <michael.berkowitz@gmail.com>"
        ],
        links: %{
          github: "https://github.com/mikowitz/ex_zipper.git"
        }
      ]
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
end
