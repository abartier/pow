defmodule Mix.Tasks.Pow.Extension.Phoenix.Gen.Templates do
  @shortdoc "Generates pow extension views and templates"

  @moduledoc """
  Generates pow extension templates for Phoenix.

  ## Usage

  Install extension templates explicitly:

      mix pow.extension.phoenix.gen.templates --extension PowResetPassword

  Use the context app configuration environment for extensions:

      mix pow.extension.phoenix.gen.templates --context-app my_app

  ## Arguments

    * `--extension PowResetPassword` extension to include in generation
    * `--context-app MyApp` app to use for path and module names
    * `--namespace my_namespace` namespace to use for path and module names
  """
  use Mix.Task

  alias Mix.{Pow, Pow.Extension, Pow.Phoenix}

  @switches [context_app: :string, extension: :keep, namespace: :string]
  @default_opts []
  @mix_task "pow.extension.phoenix.gen.templates"

  @doc false
  def run(args) do
    Pow.no_umbrella!(@mix_task)
    Pow.ensure_phoenix!(@mix_task, args)

    args
    |> Pow.parse_options(@switches, @default_opts)
    |> create_template_files()
    |> print_shell_instructions()
  end

  @extension_templates [
    {PowResetPassword, [
      {"reset_password", ~w(new edit)}
    ]}
  ]
  defp create_template_files({config, _parsed, _invalid}) do
    structure  = Phoenix.parse_structure(config)
    web_module = structure[:web_module]
    web_prefix = structure[:web_prefix]
    otp_app    = String.to_atom(Macro.underscore(structure[:context_base]))
    extensions =
      config
      |> Extension.extensions(otp_app)
      |> Enum.filter(&Keyword.has_key?(@extension_templates, &1))
      |> Enum.map(&{&1, @extension_templates[&1]})

    Enum.each(extensions, fn {module, templates} ->
      Enum.each(templates, fn {name, actions} ->
        Phoenix.create_view_file(module, name, web_module, web_prefix, config[:namespace])
        Phoenix.create_templates(module, name, web_prefix, actions, config[:namespace])
      end)
    end)

    %{extensions: extensions, otp_app: otp_app, structure: structure}
  end

  defp print_shell_instructions(%{extensions: [], otp_app: otp_app}) do
    Extension.no_extensions_error(otp_app)
  end
  defp print_shell_instructions(config), do: config
end
