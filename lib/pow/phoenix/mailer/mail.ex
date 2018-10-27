defmodule Pow.Phoenix.Mailer.Mail do
  @moduledoc """
  Module that renders html and text version of e-mails.
  """
  alias Plug.Conn
  alias Pow.{Config, Plug}

  @type t :: %__MODULE__{}

  defstruct [:user, :subject, :text, :html, :assigns]

  @doc """
  Returns a populated `%Pow.Phoenix.Mailer.Mail{}` map.

  If the configuration has `:web_mailer_module`, it will be used to find the
  template view module to call.
  """
  @spec new(Conn.t(), map(), {module(), atom()}, Keyword.t()) :: t()
  def new(conn, user, {view_module, template}, assigns) do
    config     = Plug.fetch_config(conn)
    web_module = Config.get(config, :web_mailer_module)
    namespace  = Config.get(config, :namespace)

    view_module = Pow.Phoenix.ViewHelpers.build_view_module(view_module, web_module, namespace)

    subject = subject(conn, view_module, template)
    text    = render(conn, view_module, "#{template}.text", assigns)
    html    =
      conn
      |> render(view_module, "#{template}.html", assigns)
      |> Phoenix.Template.HTML.encode_to_iodata!()
      |> IO.iodata_to_binary()

    struct(__MODULE__, user: user, subject: subject, text: text, html: html, assigns: assigns)
  end

  @spec subject(Conn.t(), module(), atom()) :: binary()
  defp subject(conn, module, mail) do
    module.subject(mail, conn: conn)
  end

  @spec render(Conn.t(), module(), binary(), Keyword.t()) :: binary()
  defp render(_conn, module, mail, assigns) do
    module.render(mail, assigns)
  end
end
