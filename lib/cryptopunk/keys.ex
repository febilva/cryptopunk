defmodule Cryptopunk.Keys do
  alias Cryptopunk.DerivationPath
  alias Cryptopunk.Keys.Private
  alias Cryptopunk.Keys.Public

  import DerivationPath, only: [is_normal: 1, is_hardened: 1]
  import Integer, only: [is_even: 1, is_odd: 1]

  @master_hmac_key "Bitcoin seed"
  @order 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141

  @spec master_key(binary()) :: Private.t()
  def master_key(seed) do
    <<private_key::binary-32, chain_code::binary-32>> = hmac_sha512(@master_hmac_key, seed)

    Private.new(private_key, chain_code)
  end

  @spec public_from_private(Private.t()) :: binary()
  def public_from_private(%Private{key: key, chain_code: chain_code}) do
    {public_key, ^key} = :crypto.generate_key(:ecdh, :secp256k1, key)

    Public.new(public_key, chain_code)
  end

  @spec derive(binary(), DerivationPath.t() | DerivationPath.raw_path()) ::
          Public.t() | Private.t()
  def derive(key, %DerivationPath{} = path) do
    raw_path = DerivationPath.to_raw_path(path)

    do_derive(key, raw_path)
  end

  def do_derive(%Private{} = private_key, []) do
    public_from_private(private_key)
  end

  def do_derive(key, {_, []}), do: key

  def do_derive(%Private{chain_code: chain_code} = private_key, [idx | tail])
      when is_normal(idx) do
    ser_public_key =
      private_key
      |> public_from_private()
      |> ser_p()

    new_private_key =
      chain_code
      |> hmac_sha512(<<ser_public_key::binary, idx::32>>)
      |> create_from_private_key(private_key)

    derive(new_private_key, tail)
  end

  def do_derive(%Private{chain_code: chain_code, key: key} = private_key, [idx | tail])
      when is_hardened(idx) do
    new_private_key =
      chain_code
      |> hmac_sha512(<<0::8, key::binary, idx::32>>)
      |> create_from_private_key(private_key)

    derive(new_private_key, tail)
  end

  def do_derive(%Public{chain_code: chain_code} = public_key, [idx | tail])
      when is_normal(idx) do
    ser_public_key = ser_p(public_key)

    new_private_key =
      chain_code
      |> hmac_sha512(<<ser_public_key::binary, idx::32>>)
      |> create_from_public_key(public_key)

    derive(new_private_key, tail)
  end

  def do_derive(%Public{}, [idx | _tail]) when is_hardened(idx) do
    raise ArgumentError, "Can not derive hardened key from public key"
  end

  defp create_from_public_key(<<l_l::256, l_r::binary>>, %Public{key: key}) do
    {:ok, new_public_key} = ExSecp256k1.public_key_tweak_add(key, l_l)

    Public.new(new_public_key, l_r)
  end

  defp create_from_private_key(
         <<new_key::256, new_chain::binary>>,
         %Private{key: <<parent_key::256>>}
       ) do
    new_private_key =
      new_key
      |> Kernel.+(parent_key)
      |> rem(@order)
      |> :binary.encode_unsigned()
      |> pad()

    Private.new(new_private_key, new_chain)
  end

  defp pad(binary) when byte_size(binary) >= 32, do: binary

  defp pad(binary) do
    bits = (32 - byte_size(binary)) * 8
    <<0::size(bits)>> <> binary
  end

  defp ser_p(%Public{key: <<0x04::8, x::256, y::256>>}) when is_even(y) do
    <<0x02::8, x::256>>
  end

  defp ser_p(%Public{key: <<0x04::8, x::256, y::256>>}) when is_odd(y) do
    <<0x03::8, x::256>>
  end

  defp hmac_sha512(key, data) do
    :crypto.mac(:hmac, :sha512, key, data)
  end
end