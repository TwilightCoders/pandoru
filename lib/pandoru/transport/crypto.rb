require 'crypt/blowfish'
require 'json'

module Pandoru
  module Transport
    # Blowfish cryptography for Pandora API encryption/decryption.
    class BlowfishCryptor
      BLOCK_SIZE = 8

      def initialize(key)
        @cipher = Crypt::Blowfish.new(key)
      end

      def encrypt(data)
        padded_data = add_padding(data)

        # Encrypt block by block for consistency with decrypt
        blocks = padded_data.scan(/.{#{BLOCK_SIZE}}/m)
        encrypted = blocks.map { |block| @cipher.encrypt_block(block) }.join

        encode_hex(encrypted)
      end

      def decrypt(data, strip_padding: true)
        return '' if data.empty?
        decoded_data = decode_hex(data)

        # Decrypt block by block (decrypt_string only does one block!)
        blocks = decoded_data.scan(/.{#{BLOCK_SIZE}}/m)
        decrypted = blocks.map { |block| @cipher.decrypt_block(block) }.join

        strip_padding ? self.class.strip_padding(decrypted) : decrypted
      end

      private

      def add_padding(data)
        pad_size = BLOCK_SIZE - (data.bytesize % BLOCK_SIZE)
        padding = pad_size.chr * pad_size
        data + padding
      end

      def self.strip_padding(data)
        pad_size = data[-1].ord
        computed_padding = pad_size.chr * pad_size

        raise ArgumentError, "Invalid padding" unless data[-pad_size..-1] == computed_padding

        data[0...-pad_size]
      end

      def decode_hex(data)
        return '' if data.empty?
        [data.upcase].pack('H*')
      end

      def encode_hex(data)
        data.unpack1('H*').downcase.encode('utf-8')
      end
    end

    # Pandora Blowfish Encryptor: encrypts requests and decrypts responses /
    # the sync time using a pair of Blowfish ciphers.
    class Encryptor
      def initialize(decryption_key, encryption_key)
        @bf_out = BlowfishCryptor.new(encryption_key)
        @bf_in = BlowfishCryptor.new(decryption_key)
      end

      def encrypt(data)
        @bf_out.encrypt(data)
      end

      def decrypt(data)
        JSON.parse(@bf_in.decrypt(data))
      end

      def decrypt_sync_time(data)
        decrypted = @bf_in.decrypt(data, strip_padding: false)
        # Extract the sync time: skip the first 4 bytes, drop the last 2
        # (matches Python's [4:-2] slice). Stored as an ASCII Unix timestamp.
        decrypted[4...-2].to_i
      end
    end
  end
end
