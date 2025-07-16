require 'spec_helper'

RSpec.describe Pandoru::PandoruError do
  describe 'inheritance hierarchy' do
    it 'inherits from StandardError' do
      expect(described_class.ancestors).to include(StandardError)
    end
  end

  describe '#initialize' do
    it 'accepts a message' do
      error = described_class.new('Test error')
      expect(error.message).to eq('Test error')
    end

    it 'accepts no arguments' do
      error = described_class.new
      expect(error.message).to eq('PandoruError')
    end
  end
end

RSpec.describe Pandoru::APIError do
  describe 'inheritance' do
    it 'inherits from PandoruError' do
      expect(described_class.ancestors).to include(Pandoru::PandoruError)
    end
  end

  describe '#initialize' do
    it 'accepts message and error code' do
      error = described_class.new('API error', 1001)
      expect(error.message).to eq('API error')
      expect(error.error_code).to eq(1001)
    end

    it 'works with just message' do
      error = described_class.new('API error')
      expect(error.message).to eq('API error')
      expect(error.error_code).to be_nil
    end
  end
end

RSpec.describe Pandoru::InvalidAuthTokenError do
  describe 'inheritance' do
    it 'inherits from APIError' do
      expect(described_class.ancestors).to include(Pandoru::APIError)
    end
  end

  describe '#initialize' do
    it 'sets default message' do
      error = described_class.new
      expect(error.message).to eq('Invalid auth token')
    end

    it 'accepts custom message' do
      error = described_class.new('Custom auth error')
      expect(error.message).to eq('Custom auth error')
    end
  end
end

RSpec.describe Pandoru::InvalidPartnerLogin do
  describe 'inheritance' do
    it 'inherits from APIError' do
      expect(described_class.ancestors).to include(Pandoru::APIError)
    end
  end

  describe '#initialize' do
    it 'sets default message' do
      error = described_class.new
      expect(error.message).to eq('Invalid partner login')
    end
  end
end

RSpec.describe Pandoru::InvalidUserLogin do
  describe 'inheritance' do
    it 'inherits from APIError' do
      expect(described_class.ancestors).to include(Pandoru::APIError)
    end
  end

  describe '#initialize' do
    it 'sets default message' do
      error = described_class.new
      expect(error.message).to eq('Invalid user login')
    end
  end
end

RSpec.describe Pandoru::InvalidRequestError do
  describe 'inheritance' do
    it 'inherits from APIError' do
      expect(described_class.ancestors).to include(Pandoru::APIError)
    end
  end

  describe '#initialize' do
    it 'sets default message' do
      error = described_class.new
      expect(error.message).to eq('Invalid request')
    end
  end
end

RSpec.describe Pandoru::InvalidConfigError do
  describe 'inheritance' do
    it 'inherits from PandoruError' do
      expect(described_class.ancestors).to include(Pandoru::PandoruError)
    end
  end

  describe '#initialize' do
    it 'sets default message' do
      error = described_class.new
      expect(error.message).to eq('Invalid configuration')
    end

    it 'accepts custom message' do
      error = described_class.new('Custom config error')
      expect(error.message).to eq('Custom config error')
    end
  end
end

RSpec.describe Pandoru::NetworkError do
  describe 'inheritance' do
    it 'inherits from PandoruError' do
      expect(described_class.ancestors).to include(Pandoru::PandoruError)
    end
  end

  describe '#initialize' do
    it 'sets default message' do
      error = described_class.new
      expect(error.message).to eq('Network error')
    end

    it 'accepts custom message' do
      error = described_class.new('Connection timeout')
      expect(error.message).to eq('Connection timeout')
    end
  end
end

RSpec.describe 'Error mappings' do
  describe 'API_ERROR_MAP' do
    it 'maps error codes to error classes correctly' do
      expect(Pandoru::API_ERROR_MAP[0]).to eq(Pandoru::InvalidPartnerLogin)
      expect(Pandoru::API_ERROR_MAP[1]).to eq(Pandoru::InvalidAuthTokenError)
      expect(Pandoru::API_ERROR_MAP[2]).to eq(Pandoru::InvalidUserLogin)
      expect(Pandoru::API_ERROR_MAP[5]).to eq(Pandoru::InvalidRequestError)
      expect(Pandoru::API_ERROR_MAP[1001]).to eq(Pandoru::InvalidAuthTokenError)
      expect(Pandoru::API_ERROR_MAP[1002]).to eq(Pandoru::InvalidPartnerLogin)
      expect(Pandoru::API_ERROR_MAP[1012]).to eq(Pandoru::InvalidUserLogin)
    end
  end

  describe '.api_error_for_code' do
    it 'returns correct error class for known codes' do
      expect(Pandoru.api_error_for_code(0)).to eq(Pandoru::InvalidPartnerLogin)
      expect(Pandoru.api_error_for_code(1)).to eq(Pandoru::InvalidAuthTokenError)
      expect(Pandoru.api_error_for_code(2)).to eq(Pandoru::InvalidUserLogin)
      expect(Pandoru.api_error_for_code(5)).to eq(Pandoru::InvalidRequestError)
      expect(Pandoru.api_error_for_code(1001)).to eq(Pandoru::InvalidAuthTokenError)
      expect(Pandoru.api_error_for_code(1002)).to eq(Pandoru::InvalidPartnerLogin)
      expect(Pandoru.api_error_for_code(1012)).to eq(Pandoru::InvalidUserLogin)
    end

    it 'returns APIError for unknown codes' do
      expect(Pandoru.api_error_for_code(99999)).to eq(Pandoru::APIError)
      expect(Pandoru.api_error_for_code(-1)).to eq(Pandoru::APIError)
      expect(Pandoru.api_error_for_code(nil)).to eq(Pandoru::APIError)
    end
  end

  describe '.create_api_error' do
    it 'creates correct error instance with message and code' do
      error = Pandoru.create_api_error('Invalid login', 2)
      
      expect(error).to be_a(Pandoru::InvalidUserLogin)
      expect(error.message).to eq('Invalid login')
      expect(error.error_code).to eq(2)
    end

    it 'creates generic APIError for unknown codes' do
      error = Pandoru.create_api_error('Unknown error', 99999)
      
      expect(error).to be_a(Pandoru::APIError)
      expect(error.message).to eq('Unknown error')
      expect(error.error_code).to eq(99999)
    end

    it 'handles missing error code' do
      error = Pandoru.create_api_error('Generic error')
      
      expect(error).to be_a(Pandoru::APIError)
      expect(error.message).to eq('Generic error')
      expect(error.error_code).to be_nil
    end
  end
end
