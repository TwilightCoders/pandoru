# Pandora API client building.
#
# Pandoru::ClientBuilders holds the low-level builders that turn a settings
# hash into a configured APIClient; Pandoru::ClientBuilder is the public facade
# over them. Listener credentials are resolved separately by Pandoru::Credentials
# (which also reads pianobar/pydora config files) — config files are no longer
# parsed here.

module Pandoru
  # Low-level builders: settings hash -> APIClient.
  module ClientBuilders
    # Key/value hash that normalizes setting keys (upcased) and can map aliases.
    class TranslatingHash < Hash
      def self.key_translations
        @key_translations ||= {}
      end

      def self.value_translations
        @value_translations ||= {}
      end

      def initialize(initial = nil)
        super()
        return unless initial

        if initial.respond_to?(:each_pair)
          initial.each_pair { |k, v| put(k, v) }
        else
          initial.each { |k, v| put(k, v) }
        end
      end

      def was_translated(from_key, to_key)
        # Override in subclasses for logging.
      end

      def translate_key(key)
        key_str = key.to_s.strip.upcase
        to_key = self.class.key_translations[key_str]
        if to_key
          was_translated(key_str, to_key)
          to_key
        else
          key_str
        end
      end

      def translate_value(key, value)
        value = value.strip if value.respond_to?(:strip)
        translator = self.class.value_translations[key]
        translator ? translator.call(value) : value
      end

      def put(key, value)
        translated_key = translate_key(key)
        store(translated_key, translate_value(translated_key, value))
      end

      def []=(key, value)
        put(key, value)
      end
    end

    # Settings hash with deprecated-key warnings.
    class SettingsHash < TranslatingHash
      def was_translated(from_key, to_key)
        Pandoru.logger&.warn("Setting key '#{from_key}' is deprecated, use '#{to_key}' instead")
      end
    end

    # Builds an APIClient from a settings hash (uppercased string keys).
    #
    # Required: DECRYPTION_KEY, ENCRYPTION_KEY, PARTNER_USER, PARTNER_PASSWORD,
    # DEVICE. Optional: API_HOST, PROXY, AUDIO_QUALITY.
    class APIClientBuilder
      DEFAULT_CLIENT_CLASS = Client::APIClient

      def initialize(client_class: nil)
        @client_class = client_class || DEFAULT_CLIENT_CLASS
      end

      def build_from_settings_hash(settings)
        cryptor = Transport::Encryptor.new(
          settings["DECRYPTION_KEY"],
          settings["ENCRYPTION_KEY"]
        )

        transport = Transport::APITransport.new(
          cryptor,
          api_host: settings["API_HOST"],
          proxy: settings["PROXY"]
        )

        @client_class.new(
          transport,
          settings["PARTNER_USER"],
          settings["PARTNER_PASSWORD"],
          settings["DEVICE"],
          default_audio_quality: settings["AUDIO_QUALITY"] || Client::BaseAPIClient::MED_AUDIO_QUALITY
        )
      end
    end

    # Builds a client from a settings hash, normalizing keys first.
    class SettingsHashBuilder < APIClientBuilder
      def initialize(settings, **kwargs)
        super(**kwargs)
        @settings = SettingsHash.new(settings)
      end

      def build
        build_from_settings_hash(@settings)
      end
    end

    # The canonical "android" partner. Note the distinction between the partner
    # *username* ("android") and the *device model* ("android-generic"). Keys
    # are oriented for the Encryptor's (decryption_key, encryption_key) order.
    DEFAULT_SETTINGS = {
      "PARTNER_USER" => "android",
      "PARTNER_PASSWORD" => "AC7IBG09A3DTSYM4R41UJWL07VLN8JI7",
      "DEVICE" => "android-generic",
      "DECRYPTION_KEY" => "R=U!LH$O2B#",
      "ENCRYPTION_KEY" => "6#26FRL$ZWD",
      "API_HOST" => "tuner.pandora.com"
    }.freeze

    module_function

    def from_settings_hash(settings, **options)
      SettingsHashBuilder.new(settings, **options).build
    end

    def default_client(**options)
      from_settings_hash(DEFAULT_SETTINGS.merge(options))
    end
  end

  # Public facade: build an APIClient from a config hash (or the built-in
  # defaults). Credentials are supplied separately via Pandoru::Credentials and
  # client.login — not through this builder.
  class ClientBuilder
    attr_reader :config

    DEFAULTS = {
      device: 'android-generic',
      encrypt_password: true,
      rpc_host: 'tuner.pandora.com',
      rpc_path: '/services/json/',
      rpc_tls_port: 443
    }.freeze

    def initialize(config_data = {})
      unless config_data.is_a?(Hash)
        raise ArgumentError,
              "ClientBuilder accepts a config Hash; file-based config was removed " \
              "in 0.3.0 — resolve credentials via Pandoru::Credentials instead"
      end

      @config = DEFAULTS.merge(config_data.transform_keys(&:to_sym))
    end

    def build
      string_config = @config.transform_keys(&:to_s).transform_keys(&:upcase)

      mapped_config = {
        'ENCRYPTION_KEY' => string_config['ENCRYPTION_KEY'] || '6#26FRL$ZWD',
        'DECRYPTION_KEY' => string_config['DECRYPTION_KEY'] || 'R=U!LH$O2B#',
        'PARTNER_USER' => string_config['PARTNER_USER'] || 'android',
        'PARTNER_PASSWORD' => string_config['PARTNER_PASSWORD'] || 'AC7IBG09A3DTSYM4R41UJWL07VLN8JI7',
        'DEVICE' => string_config['DEVICE'] || 'android-generic',
        'API_HOST' => (string_config['RPC_HOST'] || string_config['HOST'] || 'tuner.pandora.com'),
        'PROXY' => string_config['CONTROL_PROXY'],
        'AUDIO_QUALITY' => string_config['AUDIO_QUALITY'] || Client::BaseAPIClient::MED_AUDIO_QUALITY
      }.compact

      if string_config['RPC_TLS_PORT']
        port = string_config['RPC_TLS_PORT'].to_i
        mapped_config['API_HOST'] = "https://#{mapped_config['API_HOST']}:#{port}/services/json/" if port > 0
      elsif mapped_config['API_HOST'] == 'tuner.pandora.com'
        mapped_config['API_HOST'] = 'https://tuner.pandora.com/services/json/'
      end

      ClientBuilders.from_settings_hash(mapped_config)
    end
  end
end
