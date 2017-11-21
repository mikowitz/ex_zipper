use Mix.Config

#     config(:ex_zipper, key: :value)
#
# And access this configuration in your application as:
#
#     Application.get_env(:ex_zipper, :key)
#
# Or configure a 3rd-party app:
#
#     config(:logger, level: :info)
#

# mix_test_watch
if Mix.env() == :dev do
  config :mix_test_watch,
    clear: true,
    tasks: [
      "test",
      "credo --strict",
      "docs"
    ]
end

# Example per-environment config:
#
#     import_config("#{Mix.env}.exs")
