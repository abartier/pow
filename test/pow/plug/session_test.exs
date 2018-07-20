defmodule Pow.Plug.SessionTest do
  use ExUnit.Case
  doctest Pow.Plug.Session

  alias Pow.{Config, Plug, Plug.Session}
  alias Pow.Test.{ConnHelpers, EtsCacheMock}

  @default_opts [
    current_user_assigns_key: :current_user,
    session_key: "auth",
    cache_store_backend: EtsCacheMock
  ]

  setup do
    EtsCacheMock.init()
    conn = :get |> ConnHelpers.conn("/") |> ConnHelpers.with_session()

    {:ok, %{conn: conn}}
  end

  test "call/2", %{conn: conn} do
    conn = Session.call(conn, @default_opts)

    assert is_nil(conn.assigns[:current_user])
    assert conn.private[:pow_config] == Config.put(@default_opts, :mod, Session)
  end

  test "call/2 with assigned current_user", %{conn: conn} do
    conn = conn
           |> Plug.assign_current_user("assigned", @default_opts)
           |> Session.call(@default_opts)

    assert conn.assigns[:current_user] == "assigned"
  end

  test "call/2 with stored current_user", %{conn: conn} do
    EtsCacheMock.put(nil, "token", "cached")

    conn = conn
           |> ConnHelpers.put_session(@default_opts[:session_key], "token")
           |> Session.call(@default_opts)

    assert conn.assigns[:current_user] == "cached"
  end

  test "call/2 with non existing cached key", %{conn: conn} do
    EtsCacheMock.put(nil, "token", "cached")

    conn = conn
           |> ConnHelpers.put_session(@default_opts[:session_key], "invalid")
           |> Session.call(@default_opts)

    assert is_nil(conn.assigns[:current_user])
  end

  test "create/2 creates new session id", %{conn: conn} do
    user = %{id: 1}
    conn = conn
           |> Session.call(@default_opts)
           |> Session.do_create(user)

    assert session_id = get_session_id(conn)
    assert is_binary(session_id)
    assert EtsCacheMock.get(nil, session_id) == user
    assert Plug.current_user(conn) == user

    conn = Session.do_create(conn, user)
    assert new_session_id = get_session_id(conn)
    assert is_binary(session_id)

    assert new_session_id != session_id
    assert EtsCacheMock.get(nil, session_id) == :not_found
    assert EtsCacheMock.get(nil, new_session_id) == user
    assert Plug.current_user(conn) == user
  end

  test "delete/1 removes session id", %{conn: conn} do
    user = %{id: 1}
    conn = conn
           |> Session.call(@default_opts)
           |> Session.do_create(user)

    assert session_id = get_session_id(conn)
    assert is_binary(session_id)
    assert EtsCacheMock.get(nil, session_id) == user
    assert Plug.current_user(conn) == user

    conn = Session.do_delete(conn)

    refute new_session_id = get_session_id(conn)
    assert is_nil(new_session_id)
    assert EtsCacheMock.get(nil, session_id) == :not_found
    assert is_nil(Plug.current_user(conn))
  end

  describe "with EtsCache backend" do
    test "stores through CredentialsCache", %{conn: conn} do
      sesion_key = "auth"
      config     = [session_key: sesion_key]
      token      = "credentials_cache_test"
      Pow.Store.CredentialsCache.put(config, token, "cached")

      :timer.sleep(100)

      conn = conn
             |> ConnHelpers.put_session("auth", token)
             |> Session.call(session_key: "auth")

      assert conn.assigns[:current_user] == "cached"
    end
  end

  def get_session_id(conn) do
    conn.private[:plug_session][@default_opts[:session_key]]
  end
end