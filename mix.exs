defmodule AsyncList.MixProject do
  use Mix.Project

  def project do
    [
      app: :async_list,
      version: "0.1.0",
      elixir: "~> 1.7",
      start_permanent: Mix.env() == :prod,
      deps: deps()
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
      {:currying, "~> 1.0.3"},
      {:exprintf, "~> 0.2.1"},
      {:typed_struct, "~> 0.1.4"},
      {:httpoison, "~> 1.4"}
    ]
  end
end
