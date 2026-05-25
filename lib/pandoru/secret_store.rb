require 'open3'
require 'json'

module Pandoru
  # Portable secret storage: keeps the Pandora credential out of any plaintext
  # file by delegating to the host OS's native secret service. There's no solid
  # cross-platform Ruby gem for this, so we shell out to each platform's tool,
  # the way fastlane et al. do:
  #
  #   macOS   → security        (Keychain)
  #   Linux   → secret-tool      (libsecret / Secret Service: GNOME Keyring, KWallet)
  #   Windows → Credential Manager (not yet wired — see Adapters::Windows)
  #
  # The credential is stored as a single JSON blob { "username", "password" }
  # under one fixed key, so retrieval is uniform across backends and we never
  # need to enumerate the store to discover the username. Everything degrades
  # gracefully: with no working backend, fetch returns nil and the resolver
  # falls through to the config file.
  module SecretStore
    SERVICE = 'pandoru'

    # Shells out, returning [stdout, success?]. Injectable so adapters can be
    # unit-tested without touching a real keychain.
    DEFAULT_RUNNER = lambda do |cmd, stdin_data|
      opts = { err: File::NULL }
      opts[:stdin_data] = stdin_data if stdin_data
      out, status = Open3.capture2(*cmd, **opts)
      [out, status.success?]
    rescue Errno::ENOENT
      ['', false]
    end

    module_function

    # The first available adapter for this host, or a Null adapter.
    def adapter(runner: DEFAULT_RUNNER)
      [Adapters::MacOS, Adapters::SecretTool, Adapters::Windows]
        .map { |klass| klass.new(runner: runner) }
        .find(&:available?) || Adapters::Null.new(runner: runner)
    end

    def available?(adapter: adapter())
      !adapter.is_a?(Adapters::Null)
    end

    def backend_name(adapter: adapter())
      adapter.name
    end

    # [username, password] from the store, or nil if absent/unreadable.
    def fetch(service: SERVICE, adapter: adapter())
      raw = adapter.read(service)
      return nil if raw.nil? || raw.strip.empty?

      data = JSON.parse(raw)
      username = data['username']
      password = data['password']
      return nil unless present?(username) && present?(password)

      [username, password]
    rescue JSON::ParserError
      nil
    end

    def store(username, password, service: SERVICE, adapter: adapter())
      adapter.write(service, JSON.generate('username' => username, 'password' => password))
    end

    def delete(service: SERVICE, adapter: adapter())
      adapter.delete(service)
    end

    def present?(value)
      !value.nil? && !value.to_s.strip.empty?
    end

    # Per-OS adapters. Each maps the generic read/write/delete of an opaque
    # secret string to the native CLI; all I/O goes through the injected runner.
    module Adapters
      class Base
        def initialize(runner: DEFAULT_RUNNER)
          @runner = runner
        end

        def name = self.class.name.split('::').last

        private

        def run(cmd, stdin_data: nil)
          @runner.call(cmd, stdin_data)
        end

        def which?(tool)
          _out, ok = run(['which', tool])
          ok
        end
      end

      # macOS Keychain via `security`. Account is fixed to the service name; the
      # secret blob is the password slot.
      class MacOS < Base
        def name = 'macOS Keychain'

        def available?
          RUBY_PLATFORM.include?('darwin') && which?('security')
        end

        def read(service)
          out, ok = run(['security', 'find-generic-password', '-s', service, '-w'])
          ok ? out.chomp : nil
        end

        def write(service, secret)
          _out, ok = run(['security', 'add-generic-password', '-U',
                          '-s', service, '-a', service, '-w', secret,
                          '-D', 'application password', '-l', service])
          ok
        end

        def delete(service)
          _out, ok = run(['security', 'delete-generic-password', '-s', service])
          ok
        end
      end

      # Linux libsecret via `secret-tool` (Secret Service: GNOME Keyring/KWallet).
      class SecretTool < Base
        def name = 'libsecret (secret-tool)'

        def available?
          RUBY_PLATFORM.include?('linux') && which?('secret-tool')
        end

        def read(service)
          out, ok = run(['secret-tool', 'lookup', 'service', service])
          ok ? out.chomp : nil
        end

        def write(service, secret)
          _out, ok = run(['secret-tool', 'store', '--label', service, 'service', service],
                         stdin_data: secret)
          ok
        end

        def delete(service)
          _out, ok = run(['secret-tool', 'clear', 'service', service])
          ok
        end
      end

      # Windows Credential Manager. Left unwired: doing it without a gem means a
      # PowerShell + Win32 CredRead/CredWrite P/Invoke shim, which can't be
      # verified here. Reports unavailable so Windows falls back to the config
      # file. Implement read/write/delete against `cmdkey`/PowerShell to enable.
      class Windows < Base
        def name = 'Windows Credential Manager (unsupported)'
        def available? = false
        def read(_service) = nil
        def write(_service, _secret) = false
        def delete(_service) = false
      end

      # No native store available — everything no-ops, resolver uses the file.
      class Null < Base
        def name = 'none'
        def available? = false
        def read(_service) = nil
        def write(_service, _secret) = false
        def delete(_service) = false
      end
    end
  end
end
