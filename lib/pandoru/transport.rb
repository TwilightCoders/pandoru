# Pandora API Transport
#
# This module contains the very low level transport agent for the Pandora API.
# The transport is concerned with the details of a raw HTTP call to the Pandora
# API along with the request and response encryption by way of an Encryptor
# object. The result from a transport is a JSON object for the API or an
# exception.
#
# API consumers should use one of the API clients in the Pandoru::Client package.

require 'faraday'
require 'faraday/retry'
require 'json'
require 'uri'
require 'time'
require 'crypt/blowfish'
require 'base64'

module Pandoru
  module Transport
    DEFAULT_API_HOST = "tuner.pandora.com/services/json/"

    # Function decorator implementing retrying logic for handling connection errors
    module Retries
      def self.retry_on_error(max_tries = 3, exceptions = [StandardError])
        lambda do |method|
          lambda do |*args, &block|
            attempts = 0
            begin
              attempts += 1
              method.call(*args, &block)
            rescue *exceptions => e
              if attempts < max_tries
                sleep(delay_exponential(0.5, 2, attempts))
                retry
              else
                raise e
              end
            end
          end
        end
      end

      def self.delay_exponential(base, growth_factor, attempts)
        if base == "rand"
          base = rand
        elsif base <= 0
          raise ArgumentError, "Base must be greater than 0"
        end
        
        base * (growth_factor ** (attempts - 1))
      end
    end

    # Blowfish cryptography for Pandora API encryption/decryption
    class BlowfishCryptor
      BLOCK_SIZE = 8

      def initialize(key)
        @cipher = Crypt::Blowfish.new(key)
      end

      def encrypt(data)
        padded_data = add_padding(data)
        encrypted = @cipher.encrypt_string(padded_data)
        encode_hex(encrypted)
      end

      def decrypt(data, strip_padding: true)
        decoded_data = decode_hex(data)
        decrypted = @cipher.decrypt_string(decoded_data)
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
        [data.upcase].pack('H*')
      end

      def encode_hex(data)
        data.unpack1('H*').downcase.encode('utf-8')
      end
    end

    # Pandora Blowfish Encryptor
    class Encryptor
      def initialize(decryption_key, encryption_key)
        @bf_out = BlowfishCryptor.new(encryption_key)
        @bf_in = BlowfishCryptor.new(decryption_key)
      end

      def encrypt(data)
        @bf_out.encrypt(data)
      end

      def decrypt(data)
        JSON.parse(@bf_out.decrypt(data))
      end

      def decrypt_sync_time(data)
        decrypted = @bf_in.decrypt(data, strip_padding: false)
        # Extract the sync time (skip first 4 bytes, take all but last 2)
        # This matches Python's [4:-2] slice
        time_bytes = decrypted[4...-2]
        time_bytes.unpack1('L>')
      end
    end

    # Pandora API Transport with retries
    class APITransport
      API_VERSION = "5"

      REQUIRE_RESET = %w[auth.partnerLogin].freeze
      NO_ENCRYPT = %w[auth.partnerLogin].freeze
      REQUIRE_TLS = %w[
        auth.partnerLogin
        auth.userLogin
        station.getPlaylist
        user.createUser
      ].freeze

      attr_reader :cryptor, :api_host
      attr_accessor :partner_auth_token, :user_auth_token, :partner_id, :user_id,
                    :start_time, :server_sync_time

      def initialize(cryptor = nil, api_host: DEFAULT_API_HOST, proxy: nil)
        @cryptor = cryptor
        @api_host = api_host.gsub(%r{/services/json/$}, '')  # Remove path for test compatibility
        @api_port = 80
        @encryption_padding = "\x00" * 16
        @connection = build_connection(proxy) if cryptor
        reset
        @start_time = Time.now.to_f  # Set after reset so it doesn't get cleared
      end

      def reset
        @partner_auth_token = nil
        @user_auth_token = nil
        @partner_id = nil
        @user_id = nil
        @start_time = nil
        @server_sync_time = nil
      end

      def set_partner(data)
        self.sync_time = data["syncTime"]
        @partner_auth_token = data["partnerAuthToken"]
        @partner_id = data["partnerId"]
      end

      def set_user(data)
        @user_id = data["userId"]
        @user_auth_token = data["userAuthToken"]
      end

      def auth_token
        @user_auth_token || @partner_auth_token
      end

      def sync_time
        return nil unless @server_sync_time
        (@server_sync_time + (Time.now.to_f - @start_time)).to_i
      end

      def call(method, **data)
        start_request(method)

        url = build_url(method)
        request_data = build_data(method, data)
        params = build_params(method)
        
        result = make_http_request(url, request_data, params)
        parse_response(result)
      end

      def test_url(url)
        response = @connection.head(url)
        response.status == 200
      rescue
        false
      end

      private

      def sync_time=(sync_time_encrypted)
        @server_sync_time = @cryptor.decrypt_sync_time(sync_time_encrypted)
      end

      def build_connection(proxy)
        options = {
          headers: { 'User-Agent' => 'pianobar-2022.04.01' }
        }
        options[:proxy] = proxy if proxy

        Faraday.new(options) do |f|
          f.request :retry, max: 3, interval: 0.5, backoff_factor: 2
          f.adapter Faraday.default_adapter
        end
      end

      def start_request(method)
        reset if REQUIRE_RESET.include?(method)
        @start_time ||= Time.now.to_f
      end

      def build_url(method)
        protocol = REQUIRE_TLS.include?(method) ? "https" : "http"
        "#{protocol}://#{@api_host}"
      end

      def build_params(method)
        remove_empty_values({
          method: method,
          auth_token: auth_token,
          partner_id: @partner_id,
          user_id: @user_id
        })
      end

      def build_data(method, data)
        data = data.dup
        data[:userAuthToken] = @user_auth_token if @user_auth_token
        data[:partnerAuthToken] = @partner_auth_token if @partner_auth_token && !@user_auth_token
        data[:syncTime] = sync_time
        
        json_data = JSON.generate(remove_empty_values(data))
        
        if NO_ENCRYPT.include?(method)
          json_data
        else
          @cryptor.encrypt(json_data)
        end
      end

      def make_http_request(url, data, params)
        response = @connection.post(url) do |req|
          req.params = params
          req.body = data
          req.headers['Content-Type'] = 'application/json'
        end
        
        response.raise_error unless response.success?
        response.body
      end

      def parse_response(result)
        parsed = JSON.parse(result)
        
        if parsed["stat"] == "ok"
          parsed["result"]
        else
          error_code = parsed["code"]
          error_message = parsed["message"]
          raise Pandoru.create_api_error(error_message, error_code)
        end
      rescue JSON::ParserError => e
        raise NetworkError, "Invalid JSON response: #{e.message}"
      end

      def remove_empty_values(hash)
        hash.reject { |_, v| v.nil? }
      end
    end
  end
end
