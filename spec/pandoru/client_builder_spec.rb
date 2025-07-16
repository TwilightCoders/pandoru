require 'spec_helper'

RSpec.describe Pandoru::ClientBuilder do
  let(:config_data) do
    {
      'device' => 'android-generic',
      'encryption_key' => 'test_key',
      'decryption_key' => 'test_key',
      'partner_user' => 'pandora one',
      'partner_password' => 'partner_pass',
      'host' => 'tuner.pandora.com'
    }
  end

  describe '#initialize' do
    it 'accepts a configuration hash merged over the defaults' do
      builder = described_class.new(config_data)
      expect(builder.config[:device]).to eq('android-generic')
      expect(builder.config[:partner_user]).to eq('pandora one')
      expect(builder.config[:rpc_host]).to eq('tuner.pandora.com') # default
    end

    it 'uses defaults when no config is given' do
      builder = described_class.new
      expect(builder.config[:device]).to eq('android-generic')
      expect(builder.config[:encrypt_password]).to eq(true)
      expect(builder.config[:rpc_host]).to eq('tuner.pandora.com')
      expect(builder.config[:rpc_tls_port]).to eq(443)
    end

    it 'rejects a non-Hash argument (file-based config was removed)' do
      expect { described_class.new('/path/to/pianobar.cfg') }.to raise_error(ArgumentError)
    end
  end

  describe '#build' do
    it 'returns an APIClient with an APITransport' do
      client = described_class.new(config_data).build
      expect(client).to be_a(Pandoru::APIClient)
      expect(client.transport).to be_a(Pandoru::APITransport)
    end

    it 'configures the transport for TLS on the default host' do
      transport = described_class.new(config_data).build.transport
      expect(transport.instance_variable_get(:@api_host)).to eq('tuner.pandora.com')
      expect(transport.instance_variable_get(:@api_port)).to eq(443)
      expect(transport.instance_variable_get(:@api_tls)).to eq(true)
    end

    context 'with default partner credentials' do
      it 'uses the "android" partner username, not the device model' do
        client = described_class.new.build
        # "android" is the partner *username*; "android-generic" is the
        # *device model*. Sending the device model as the username fails
        # partnerLogin (INVALID_PARTNER_LOGIN).
        expect(client.partner_user).to eq('android')
        expect(client.device).to eq('android-generic')
      end

      it 'orients the encryption/decryption keys correctly' do
        cryptor = described_class.new.build.transport.cryptor
        probe = '{"x":1}'

        bf_out = cryptor.instance_variable_get(:@bf_out)
        bf_in  = cryptor.instance_variable_get(:@bf_in)

        expect(bf_out.encrypt(probe))
          .to eq(Pandoru::Transport::BlowfishCryptor.new('6#26FRL$ZWD').encrypt(probe))
        expect(bf_in.encrypt(probe))
          .to eq(Pandoru::Transport::BlowfishCryptor.new('R=U!LH$O2B#').encrypt(probe))
      end
    end

    context 'with a custom host and port' do
      it 'uses the custom host and port' do
        transport = described_class
                    .new(config_data.merge('rpc_host' => 'custom.pandora.com', 'rpc_tls_port' => 8443))
                    .build.transport
        expect(transport.instance_variable_get(:@api_host)).to eq('custom.pandora.com')
        expect(transport.instance_variable_get(:@api_port)).to eq(8443)
      end
    end
  end
end
