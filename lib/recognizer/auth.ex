defmodule Recognizer.Auth do
  @moduledoc """
  Authentication functionality
  """

  alias Recognizer.{Accounts, Audiences, Guardian}
  alias Recognizer.Schemas.{Audience, User}

  defdelegate decode_and_verify(token), to: Guardian

  @doc """
  Exposes the Guardian token refresh functionality
  """
  @spec exchange(String.t(), String.t()) :: {:ok, String.t(), String.t()} | :error
  def exchange(refresh_token, audience_token) do
    with %Audience{id: aud} <- Audiences.by_token(audience_token),
         {:ok, {_old_access_token, _old_claims}, {access_token, _claims}} <-
           Guardian.exchange(refresh_token, "refresh", "access", aud: aud) do
      {:ok, access_token, refresh_token}
    else
      _ -> :error
    end
  end

  @doc """
  Transforms a string into a lowercase base 16 encoded hash
  """
  @spec hash_password(String.t()) :: String.t()
  def hash_password(password) do
    :sha256
    |> :crypto.hmac(secret_key_base(), password)
    |> Base.encode16(case: :lower)
  end

  @doc """
  Login in a user by looking them up via email, compares password hashes, creating and signing a new JWT when valid.
  """
  @spec login(String.t(), String.t(), String.t()) :: {:ok, String.t(), String.t()} | :error
  def login(email, password, audience_token) do
    with %Audience{id: aud} <- Audiences.by_token(audience_token),
         %User{password_hash: expected_hash} = user <- Accounts.get_by(email: email),
         hashed_password <- hash_password(password),
         true <- Plug.Crypto.secure_compare(expected_hash, hashed_password) do
      generate_signed_token(user, aud)
    else
      _ -> :error
    end
  end

  defp generate_signed_token(%User{} = user, aud) do
    with {:ok, access_token, _access_claims} <- access_token(user),
         {:ok, refresh_token, _refresh_claims} <- refresh_token(user, aud) do
      {:ok, access_token, refresh_token}
    end
  end

  defp access_token(%User{roles: roles} = user) do
    simple_roles = simplify_roles(roles)
    Guardian.encode_and_sign(user, %{scope: simple_roles}, token_type: "access", ttl: {7, :days})
  end

  defp refresh_token(user, aud) do
    Guardian.encode_and_sign(user, %{aud: aud},
      token_type: "refresh",
      ttl: {4, :weeks}
    )
  end

  defp secret_key_base, do: Map.get(System.get_env(), "SECRET_KEY_BASE", "a really good secret")

  defp simplify_roles(roles) when is_list(roles), do: Enum.map(roles, &Map.get(&1, :name))
  defp simplify_roles(_), do: []
end
