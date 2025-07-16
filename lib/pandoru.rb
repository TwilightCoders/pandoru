require_relative 'pandoru/version'
require_relative 'pandoru/errors'
require_relative 'pandoru/transport'
require_relative 'pandoru/client'
require_relative 'pandoru/client_builder'
require_relative 'pandoru/models'
require 'pathname'
require 'logger'

module Pandoru
  class << self
    attr_reader :logger

    def root(*args)
      (@root ||= Pathname.new(File.expand_path('../', __dir__))).join(*args)
    end

    def logger
      @logger ||= create_logger
    end

    def create_logger
      set_logger
    end

    def set_logger(logdev: $stdout, level: ::Logger::INFO)
      @logger = ::Logger.new(logdev).tap do |log|
        log.progname = self.name
        log.level = level
        log.formatter = proc do |severity, datetime, progname, msg|
          color_code = color_for_severity(severity)
          formatted_severity = "#{color_code}#{severity[0]}#{reset_color}"
          "#{formatted_severity} - [#{datetime.strftime('%Y-%m-%d %H:%M:%S')}] #{progname}: #{msg}\n"
        end
      end
    end

    private

    def color_for_severity(severity)
      case severity
      when 'DEBUG'
        "\e[32m"  # Green
      when 'INFO'
        "\e[36m"  # Cyan
      when 'WARN'
        "\e[33m"  # Yellow
      when 'ERROR', 'FATAL'
        "\e[31m"  # Red
      else
        "\e[0m"   # Default (no color)
      end
    end

    def reset_color
      "\e[0m"
    end
  end

  # Class aliases for convenience
  APIClient = Client::APIClient
  BaseAPIClient = Client::BaseAPIClient
  APITransport = Transport::APITransport
  
  # Error aliases
  InvalidAuthTokenError = InvalidAuthToken
  PandoraException = PandoruError
end