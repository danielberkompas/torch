defmodule Torch.MixProject do
  use Mix.Project

  @source_url "https://github.com/mojotech/torch"
  @version "3.6.3"

  def project do
    [
      app: :torch,
      version: @version,
      elixir: "~> 1.8",
      start_permanent: Mix.env() == :prod,
      compilers: [:phoenix, :gettext] ++ Mix.compilers(),
      name: "Torch",
      test_paths: ["test/mix", "test/torch"],
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ],
      elixirc_paths: elixirc_paths(Mix.env()),
      package: package(),
      docs: docs(),
      deps: deps()
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support/cases"]
  defp elixirc_paths(_env), do: ["lib"]

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:phoenix, ">= 1.3.0 and < 1.6.0"},
      {:phoenix_html, "~> 2.10"},
      {:gettext, "~> 0.16"},
      {:scrivener_ecto, ">= 1.2.1"},
      {:filtrex, "~> 0.4.1"},
      {:jason, ">= 0.0.0", only: [:dev, :test]},
      {:excoveralls, ">= 0.0.0", only: [:dev, :test]},
      {:credo, "~> 1.1", only: [:dev, :test]},
      {:ex_doc, ">= 0.0.0", only: [:dev, :test], runtime: false},
      {:ex_unit_notifier, "~> 1.0", only: [:test]},
      {:mix_test_watch, "~> 1.0", only: [:dev], runtime: false}
    ]
  end

  defp package do
    [
      description: "Rapid admin generator for Phoenix",
      maintainers: ["MojoTech"],
      licenses: ["MIT"],
      files: ~w(lib priv mix.exs README.md LICENSE.md CHANGELOG.md CODE_OF_CONDUCT.md),
      links: %{
        "Github" => @source_url
      }
    ]
  end

  defp docs do
    [
      extras: [
        "CHANGELOG.md": [title: "Changelog"],
        "CODE_OF_CONDUCT.md": [title: "Code of Conduct"],
        "LICENSE.md": [title: "License"],
        "README.md": [title: "Overview"]
      ],
      main: "readme",
      source_url: @source_url,
      source_ref: "v#{@version}",
      formatters: ["html"]
    ]
  end
end
