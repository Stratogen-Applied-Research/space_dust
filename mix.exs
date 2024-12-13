defmodule SpaceDust.MixProject do
  use Mix.Project

  def project do
    [
      app: :space_dust,
      version: "0.1.0",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      name: "Space Dust",
      source_url: "https://github.com/Stratogen-Applied-Research/space_dust",
      description: description()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:req, "~>0.5.8"},
      {:ex_doc, "~> 0.22", only: :dev, runtime: false}
    ]
  end

  defp description do
    """
    Space Dust is an astrodynamics library written in Elixir.
    """
  end

  defp package do
    [
      name: "space_dust",
      licenses: ["MIT"],
      files: ~w(lib .formatter.exs mix.exs README* LICENSE*),
      links: %{"GitHub" => "https://github.com/Stratogen-Applied-Research/space_dust"}
    ]
  end
end
