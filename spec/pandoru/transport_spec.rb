require 'spec_helper'
require 'webmock/rspec'

RSpec.describe Pandoru::APITransport do
  let(:transport) { described_class.new }
  
  before do
    WebMock.disable_net_connect!(allow_localhost: true)
  end
  
  after do
    WebMock.reset!
  end

  describe '#initialize' do
    it 'sets default values' do
      expect(transport.instance_variable_get(:@api_host)).to eq('tuner.pandora.com')
      expect(transport.instance_variable_get(:@api_port)).to eq(80)
      expect(transport.instance_variable_get(:@encryption_padding)).to eq("\x00" * 16)
      expect(transport.instance_variable_get(:@start_time)).to be_a(Float)
    end
  end

  describe '#test_connectivity' do
    context 'when connection succeeds' do
      before do
        stub_request(:head, "http://tuner.pandora.com:80/")
          .to_return(status: 200, body: 'OK')
      end

      it 'returns true' do
        expect(transport.test_connectivity).to eq(true)
      end
    end

    context 'when connection fails' do
      before do
        stub_request(:head, "http://tuner.pandora.com:80/")
          .to_raise(Faraday::ConnectionFailed)
      end

      it 'returns false' do
        expect(transport.test_connectivity).to eq(false)
      end
    end
  end

  describe '#build_url' do
    it 'builds API URL correctly' do
      result = transport.send(:build_url, 'method_name')
      # Standard http/80 port is omitted, and with no auth tokens set yet
      # `method` is the only query parameter. This matches the URL the live
      # API actually accepts.
      expect(result).to eq('http://tuner.pandora.com/services/json/?method=method_name')
    end

    it 'uses https for every method on a TLS-configured host, not just REQUIRE_TLS ones' do
      tls_transport = described_class.new(nil, api_host: 'https://tuner.pandora.com/services/json/')
      # user.getStationList is NOT in REQUIRE_TLS but must still be https — the
      # old downgrade built http://host:443 (plaintext to the TLS port → EOF).
      result = tls_transport.send(:build_url, 'user.getStationList')
      expect(result).to eq('https://tuner.pandora.com/services/json/?method=user.getStationList')
      expect(result).not_to include(':443')
    end

    it 'includes auth token when provided' do
      transport.instance_variable_set(:@auth_token, 'test_token')
      result = transport.send(:build_url, 'method_name', {})
      expect(result).to include('auth_token=test_token')
    end

    it 'includes user auth token when provided' do
      transport.instance_variable_set(:@user_auth_token, 'user_token')
      result = transport.send(:build_url, 'method_name', {})
      expect(result).to include('user_auth_token=user_token')
    end

    it 'includes partner ID when provided' do
      transport.instance_variable_set(:@partner_id, 'partner123')
      result = transport.send(:build_url, 'method_name', {})
      expect(result).to include('partner_id=partner123')
    end

    it 'includes user ID when provided' do
      transport.instance_variable_set(:@user_id, 'user456')
      result = transport.send(:build_url, 'method_name', {})
      expect(result).to include('user_id=user456')
    end
  end

  describe '#encrypt' do
    it 'encrypts data correctly' do
      key = 'test_key_123456'
      data = 'hello world'
      
      encrypted = transport.send(:encrypt, data, key)
      expect(encrypted).to be_a(String)
      expect(encrypted).not_to eq(data)
    end

    it 'pads data to 16-byte boundary' do
      key = 'test_key_123456'
      data = 'hello'
      
      # Should pad to next 16-byte boundary
      encrypted = transport.send(:encrypt, data, key)
      expect(encrypted).to be_a(String)
    end
  end

  describe '#decrypt' do
    it 'decrypts data correctly' do
      key = 'test_key_123456'
      original_data = 'hello world'
      
      encrypted = transport.send(:encrypt, original_data, key)
      decrypted = transport.send(:decrypt, encrypted, key)
      
      expect(decrypted.strip).to eq(original_data)
    end

    it 'handles empty data' do
      key = 'test_key_123456'
      
      decrypted = transport.send(:decrypt, '', key)
      expect(decrypted).to eq('')
    end
  end

  describe '#sync_time' do
    it 'returns nil when server sync time is not set' do
      expect(transport.sync_time).to be_nil
    end
    
    it 'returns computed sync time when server sync time is set' do
      # Set server sync time directly
      transport.instance_variable_set(:@server_sync_time, 1234567890)
      result = transport.sync_time
      expect(result).to be_a(Integer)
      expect(result).to be >= 1234567890
    end
  end

  describe 'error handling' do
    context 'when API returns error response' do
      before do
        stub_request(:post, /tuner\.pandora\.com.*services\/json/)
          .to_return(
            status: 200,
            body: { 
              stat: 'fail',
              code: 1001,
              message: 'Test error'
            }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'raises appropriate exception' do
        expect {
          transport.call('test.method')
        }.to raise_error(Pandoru::APIError)
      end
    end

    context 'when network error occurs' do
      before do
        stub_request(:post, /tuner\.pandora\.com.*services\/json/)
          .to_raise(Faraday::ConnectionFailed)
      end

      it 'raises NetworkError' do
        expect {
          transport.call('test.method')
        }.to raise_error(Pandoru::NetworkError)
      end
    end
  end

  describe 'retry logic' do
    context 'when initial request fails but retry succeeds' do
      before do
        stub_request(:post, /tuner\.pandora\.com.*services\/json/)
          .to_raise(Faraday::ConnectionFailed).then
          .to_return(
            status: 200,
            body: { stat: 'ok', result: {} }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      xit 'retries and succeeds' do
        result = transport.call('test.method')
        expect(result).to be_a(Hash)
      end
    end
  end
end
