defmodule ExZipper.Mixfile do
  use Mix.Project

  @name :ex_zipper
  @version "0.1.0"

  @deps [
    {:credo, github: "rrrene/credo", only: [:dev, :test], runtime: false},
    {:mix_test_watch, "~> 0.5.0", only: :dev, runtime: false},
    {:stream_data, "~> 0.3.0"}
  ]

  # ------------------------------------------------------------

  def project do
    in_production = Mix.env() == :prod

    [
      app: @name,
      version: @version,
      elixir: ">= 1.6.0-dev",
      deps: @deps,
      build_embedded: in_production
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
