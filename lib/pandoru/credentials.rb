require 'json'

module Pandoru
  # Resolves Pandora account credentials from the first source that supplies a
  # complete username/password pair, so the client works whether you prefer env
  # vars, the OS secret store, or a config file. Empty values count as absent,
  # so an unset/blank value gracefully falls through to the next source rather
  # than half-authenticating.
  #
  # Precedence (highest first):
  #
  #   1. Explicit values passed in (tests, embedding).
  #   2. ENV PANDORA_USERNAME / PANDORA_PASSWORD.
  #   3. The OS secret store (Keychain / libsecret), if a credential is stored.
  #   4. Config files, first that yields a complete pair:
  #        $PANDORU_CREDENTIALS                       (JSON; explicit override)
  #        $XDG_CONFIG_HOME/pandoru/credentials.json  (JSON; XDG, default ~/.config)
  #        ~/.pydora.cfg                              (pydora; [user] section)
  #        $XDG_CONFIG_HOME/pianobar/config           (pianobar)
  #
  # The pydora/pianobar tiers let users migrating from those tools reuse their
  # existing login without copying it into a new file.
  class Credentials
    class NotFound < StandardError; end

    Resolved = Struct.new(:username, :password, :source, keyword_init: true)

    USERNAME_KEYS = %w[username user email].freeze
    PASSWORD_KEYS = %w[password pass].freeze

    def self.resolve(username: nil, password: nil, env: ENV, home: Dir.home, secret_store: SecretStore)
      new(env: env, home: home, secret_store: secret_store)
        .resolve(username: username, password: password)
    end

    def initialize(env: ENV, home: Dir.home, secret_store: SecretStore)
      @env = env
      @home = home
      @secret_store = secret_store
    end

    def resolve(username: nil, password: nil)
      if present?(username) && present?(password)
        return Resolved.new(username: username, password: password, source: :explicit)
      end

      if present?(@env['PANDORA_USERNAME']) && present?(@env['PANDORA_PASSWORD'])
        return Resolved.new(username: @env['PANDORA_USERNAME'],
                            password: @env['PANDORA_PASSWORD'], source: :env)
      end

      if @secret_store && (creds = @secret_store.fetch)
        return Resolved.new(username: creds[0], password: creds[1], source: :secret_store)
      end

      candidate_sources.each do |path, format|
        next unless File.file?(path)
        creds = parse(path, format)
        next unless creds
        return Resolved.new(username: creds[0], password: creds[1], source: path)
      end

      raise NotFound, not_found_message
    end

    # Ordered [path, format] credential sources to try.
    def candidate_sources
      sources = []
      sources << [@env['PANDORU_CREDENTIALS'], :json] if present?(@env['PANDORU_CREDENTIALS'])
      sources << [File.join(xdg_config_home, 'pandoru', 'credentials.json'), :json]
      sources << [File.join(@home, '.pydora.cfg'), :pydora]
      sources << [File.join(xdg_config_home, 'pianobar', 'config'), :pianobar]
      sources.uniq
    end

    private

    def xdg_config_home
      present?(@env['XDG_CONFIG_HOME']) ? @env['XDG_CONFIG_HOME'] : File.join(@home, '.config')
    end

    # Returns [username, password] for the given file/format, or nil if the file
    # is unreadable or incomplete (so resolution continues to the next source).
    def parse(path, format)
      case format
      when :json     then parse_json(path)
      when :pydora   then extract(parse_ini_section(path, 'user'))
      when :pianobar then extract(parse_flat(path))
      end
    end

    def parse_json(path)
      data = JSON.parse(File.read(path))
      data.is_a?(Hash) ? extract(data) : nil
    rescue JSON::ParserError
      nil
    end

    # Flat `key = value` file (pianobar). Comments (#) and blank lines ignored.
    def parse_flat(path)
      File.foreach(path).each_with_object({}) do |line, acc|
        line = line.strip
        next if line.empty? || line.start_with?('#') || !line.include?('=')
        key, value = line.split('=', 2)
        acc[key.strip.downcase] = value.strip
      end
    end

    # INI file (pydora .cfg): return only the named section's keys. Scoping to
    # [user] matters — the [api] section's `password` is the *partner* password,
    # not the listener's.
    def parse_ini_section(path, section)
      current = nil
      File.foreach(path).each_with_object({}) do |line, acc|
        line = line.strip
        next if line.empty? || line.start_with?('#')
        if line.start_with?('[') && line.end_with?(']')
          current = line[1...-1].strip.downcase
          next
        end
        next unless current == section && line.include?('=')
        key, value = line.split('=', 2)
        acc[key.strip.downcase] = unquote(value.strip)
      end
    end

    def unquote(value)
      return value[1...-1] if value.length >= 2 &&
                              ((value.start_with?('"') && value.end_with?('"')) ||
                               (value.start_with?("'") && value.end_with?("'")))
      value
    end

    # Pull a username/password pair out of a parsed key/value hash, honoring the
    # accepted key aliases. nil unless both are present.
    def extract(hash)
      return nil unless hash.is_a?(Hash)
      username = USERNAME_KEYS.map { |k| hash[k] }.find { |v| present?(v) }
      password = PASSWORD_KEYS.map { |k| hash[k] }.find { |v| present?(v) }
      present?(username) && present?(password) ? [username, password] : nil
    end

    def present?(value)
      !value.nil? && !value.to_s.strip.empty?
    end

    def not_found_message
      checked = ['PANDORA_USERNAME / PANDORA_PASSWORD (env)',
                 'OS secret store (run pandoru-login)'] + candidate_sources.map(&:first)
      <<~MSG.strip
        No Pandora credentials found. Checked, in order:
        #{checked.map { |c| "  - #{c}" }.join("\n")}
        Store them with `pandoru-login`, provide a JSON file like
        { "username": "you@example.com", "password": "…" }, or set the
        PANDORA_USERNAME / PANDORA_PASSWORD environment variables.
      MSG
    end
  end
end
