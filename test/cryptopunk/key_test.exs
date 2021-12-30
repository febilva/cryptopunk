defmodule Cryptopunk.KeyTest do
  use ExUnit.Case

  alias Cryptopunk.Key

  describe "master_key/1" do
    test "calculates master private key from seed" do
      seed =
        <<98, 235, 236, 246, 19, 205, 197, 254, 187, 41, 62, 19, 189, 20, 24, 73, 206, 187, 198,
          83, 160, 138, 77, 155, 195, 97, 140, 111, 133, 102, 241, 26, 176, 95, 206, 198, 71, 251,
          118, 115, 134, 215, 226, 194, 62, 106, 255, 94, 15, 142, 227, 186, 152, 88, 218, 220,
          184, 63, 242, 30, 162, 59, 32, 229>>

      assert %Cryptopunk.Key{
               chain_code:
                 <<153, 249, 145, 92, 65, 77, 50, 249, 120, 90, 178, 30, 41, 27, 73, 128, 74, 201,
                   91, 250, 143, 238, 129, 247, 115, 87, 161, 107, 123, 63, 84, 243>>,
               key:
                 <<50, 8, 92, 222, 223, 155, 132, 50, 53, 227, 114, 79, 88, 11, 248, 24, 239, 76,
                   236, 39, 195, 198, 112, 133, 224, 41, 65, 138, 91, 47, 111, 43>>,
               type: :private
             } == Key.master_key(seed)
    end
  end
end