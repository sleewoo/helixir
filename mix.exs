defmodule Helixir.MixProject do
  use Mix.Project

  def project do
    [
      app: :helixir,
      version: "0.2.0",
      elixir: "~> 1.11",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      package: package(),
      name: "Helixir",
      source_url: "https://github.com/sleewoo/helixir"
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
      {:jason, "~> 1.2"}
    ]
  end

  defp description() do
    "Build Plug.Router tree from FS and provide various helpers"
  end

  defp package() do
    [
      files: ~w(lib .formatter.exs mix.exs README* LICENSE*),
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/sleewoo/helixir"},
    ]
  end
end
