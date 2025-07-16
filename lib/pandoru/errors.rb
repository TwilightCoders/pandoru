# Pandora API Exceptions

module Pandoru
  # Base exception for all Pandoru errors
  class PandoruError < StandardError
    def initialize(message = nil)
      super(message || self.class.name.split('::').last)
    end
  end

  # Network related errors
  class NetworkError < PandoruError
    def initialize(message = 'Network error')
      super(message)
    end
  end

  # Configuration related errors  
  class InvalidConfigError < PandoruError
    def initialize(message = 'Invalid configuration')
      super(message)
    end
  end

  # Parameter related errors
  class ParameterMissing < PandoruError; end

  # API related errors
  class APIError < PandoruError
    attr_reader :error_code

    def initialize(message = nil, error_code = nil)
      @error_code = error_code
      super(message)
    end
  end

  # Specific API errors
  class InvalidAuthToken < APIError
    def initialize(message = 'Invalid auth token', code = 1001)
      super(message, code)
    end
  end

  class InvalidPartnerLogin < APIError
    def initialize(message = 'Invalid partner login', code = 1002)
      super(message, code)
    end
  end

  class InvalidUserLogin < APIError
    def initialize(message = 'Invalid user login', code = 1012)
      super(message, code)
    end
  end

  class InvalidRequestError < APIError
    def initialize(message = 'Invalid request', code = 5)
      super(message, code)
    end
  end

  # All Pandora API error codes from Python reference
  API_ERRORS = {
    0 => "Internal Server Error",
    1 => "Maintenance Mode", 
    2 => "Missing API Method",
    3 => "Missing Auth Token",
    4 => "Missing Partner ID",
    5 => "Missing User ID",
    6 => "Secure Protocol Required",
    7 => "Certificate Required",
    8 => "Parameter Type Mismatch",
    9 => "Parameter Missing",
    10 => "Parameter Value Invalid",
    11 => "API Version Not Supported",
    12 => "Pandora not available in this country",
    13 => "Bad Sync Time",
    14 => "Unknown Method Name",
    15 => "Wrong Protocol - (http/https)",
    1000 => "Read Only Mode",
    1001 => "Invalid Auth Token",
    1002 => "Invalid Partner Login",
    1003 => "Listener Not Authorized - Subscription or Trial Expired",
    1004 => "User Not Authorized",
    1005 => "Station limit reached",
    1006 => "Station does not exist",
    1009 => "Device Not Found",
    1010 => "Partner Not Authorized",
    1011 => "Invalid Username",
    1012 => "Invalid Password",
    1023 => "Device Model Invalid",
    1039 => "Too many requests for a new playlist",
    9999 => "Authentication Required"
  }.freeze

  # Error code mappings to exception classes
  API_ERROR_MAP = {
    0 => InvalidPartnerLogin,
    1 => InvalidAuthToken,
    2 => InvalidUserLogin,
    5 => InvalidRequestError,
    1001 => InvalidAuthToken,
    1002 => InvalidPartnerLogin,
    1012 => InvalidUserLogin
  }

  # Factory method to create appropriate error
  def self.api_error_for_code(code)
    API_ERROR_MAP[code] || APIError
  end

  def self.create_api_error(message, code = nil)
    error_class = api_error_for_code(code)
    error_class.new(message, code)
  end

  # Create exception classes for all error codes
  API_ERRORS.each do |code, message|
    # Convert message to class name (e.g., "Invalid Auth Token" -> "InvalidAuthToken")
    class_name = message.gsub(/[^a-zA-Z0-9\s]/, '').split.map(&:capitalize).join
    next if const_defined?(class_name) # Skip if already defined

    # Create the exception class
    exception_class = Class.new(APIError) do
      define_method(:initialize) do |extended_message = "", error_code = code|
        super("#{message}#{extended_message.empty? ? '' : ": #{extended_message}"}", error_code)
      end
    end

    const_set(class_name, exception_class)
    API_ERROR_MAP[code] = exception_class unless API_ERROR_MAP.key?(code)
  end

  # Freeze the error map after all classes are created
  API_ERROR_MAP.freeze

  # Aliases for common exceptions
  module Errors
    PandoraException = PandoruError
    InvalidAuthToken = Pandoru::InvalidAuthToken
    InvalidPartnerLogin = Pandoru::InvalidPartnerLogin
    InvalidUserLogin = Pandoru::InvalidUserLogin
    ParameterMissing = Pandoru::ParameterMissing
    NetworkError = Pandoru::NetworkError
  end
end