require 'spec_helper'
require 'tmpdir'
require 'fileutils'
require 'json'

RSpec.describe Pandoru::Credentials do
  # secret_store defaults to nil so tests never touch the real OS keychain;
  # the secret-store tier is exercised explicitly below with a fake.
  def resolve(env: {}, home: '/nonexistent-home', secret_store: nil, **explicit)
    described_class.resolve(env: env, home: home, secret_store: secret_store, **explicit)
  end

  describe 'precedence' do
    it 'prefers explicit values over everything' do
      result = resolve(username: 'me', password: 'pw',
                       env: { 'PANDORA_USERNAME' => 'envu', 'PANDORA_PASSWORD' => 'envp' })
      expect(result.username).to eq('me')
      expect(result.source).to eq(:explicit)
    end

    it 'uses env vars when no explicit values are given' do
      result = resolve(env: { 'PANDORA_USERNAME' => 'envu', 'PANDORA_PASSWORD' => 'envp' })
      expect([result.username, result.password, result.source]).to eq(['envu', 'envp', :env])
    end

    it 'treats blank env vars as absent and falls through to the file' do
      Dir.mktmpdir do |home|
        write_creds(File.join(home, '.config', 'pandoru', 'credentials.json'), 'fileu', 'filep')
        result = resolve(env: { 'PANDORA_USERNAME' => '', 'PANDORA_PASSWORD' => '  ' }, home: home)
        expect(result.username).to eq('fileu')
        expect(result.source).to end_with('.config/pandoru/credentials.json')
      end
    end

    it 'ignores a partial env pair (username but no password)' do
      Dir.mktmpdir do |home|
        write_creds(File.join(home, '.config', 'pandoru', 'credentials.json'), 'fileu', 'filep')
        result = resolve(env: { 'PANDORA_USERNAME' => 'envu' }, home: home)
        expect(result.source).to end_with('.config/pandoru/credentials.json')
      end
    end

    it 'uses the secret store after env but before the file' do
      Dir.mktmpdir do |home|
        write_creds(File.join(home, '.config', 'pandoru', 'credentials.json'), 'fileu', 'filep')
        store = double('SecretStore', fetch: %w[keyu keyp])
        result = resolve(home: home, secret_store: store)
        expect([result.username, result.password, result.source]).to eq(%w[keyu keyp] << :secret_store)
      end
    end

    it 'falls through to the file when the secret store is empty' do
      Dir.mktmpdir do |home|
        write_creds(File.join(home, '.config', 'pandoru', 'credentials.json'), 'fileu', 'filep')
        store = double('SecretStore', fetch: nil)
        result = resolve(home: home, secret_store: store)
        expect(result.username).to eq('fileu')
      end
    end
  end

  describe 'file resolution' do
    it 'defaults XDG to ~/.config when XDG_CONFIG_HOME is unset' do
      Dir.mktmpdir do |home|
        write_creds(File.join(home, '.config', 'pandoru', 'credentials.json'), 'cfgu', 'cfgp')
        expect(resolve(home: home).username).to eq('cfgu')
      end
    end

    it 'honors an explicit PANDORU_CREDENTIALS path first' do
      Dir.mktmpdir do |home|
        path = File.join(home, 'custom.json')
        write_creds(path, 'customu', 'customp')
        write_creds(File.join(home, '.config', 'pandoru', 'credentials.json'), 'cfgu', 'cfgp')
        result = resolve(env: { 'PANDORU_CREDENTIALS' => path }, home: home)
        expect(result.username).to eq('customu')
      end
    end

    it 'accepts user/email and pass key aliases' do
      Dir.mktmpdir do |home|
        path = File.join(home, '.config', 'pandoru', 'credentials.json')
        FileUtils.mkdir_p(File.dirname(path))
        File.write(path, JSON.generate('email' => 'e@x.com', 'pass' => 'p'))
        result = resolve(home: home)
        expect([result.username, result.password]).to eq(['e@x.com', 'p'])
      end
    end

    it 'skips an unparseable or incomplete file and keeps looking' do
      Dir.mktmpdir do |home|
        File.write(File.join(home, 'bad.json'), 'not json{{')
        write_creds(File.join(home, '.config', 'pandoru', 'credentials.json'), 'goodu', 'goodp')
        result = resolve(env: { 'PANDORU_CREDENTIALS' => File.join(home, 'bad.json') }, home: home)
        expect(result.username).to eq('goodu')
      end
    end
  end

  describe 'pydora .cfg migration tier' do
    it 'reads the [user] section of ~/.pydora.cfg' do
      Dir.mktmpdir do |home|
        File.write(File.join(home, '.pydora.cfg'), <<~CFG)
          [user]
          username = me@pydora.com
          password = pydorapass

          [api]
          username = android
          password = AC7IBG09A3DTSYM4R41UJWL07VLN8JI7
        CFG
        result = resolve(home: home)
        expect([result.username, result.password]).to eq(['me@pydora.com', 'pydorapass'])
        expect(result.source).to end_with('.pydora.cfg')
      end
    end

    it 'never mistakes the [api] partner password for the user password' do
      Dir.mktmpdir do |home|
        # [user] omits a password → the pair is incomplete and must NOT be
        # completed from [api]'s partner password.
        File.write(File.join(home, '.pydora.cfg'), <<~CFG)
          [user]
          username = me@pydora.com

          [api]
          password = AC7IBG09A3DTSYM4R41UJWL07VLN8JI7
        CFG
        expect { resolve(home: home) }.to raise_error(described_class::NotFound)
      end
    end
  end

  describe 'pianobar config migration tier' do
    it 'reads user/password from ~/.config/pianobar/config' do
      Dir.mktmpdir do |home|
        path = File.join(home, '.config', 'pianobar', 'config')
        FileUtils.mkdir_p(File.dirname(path))
        File.write(path, <<~CFG)
          user = me@pianobar.com
          password = pianobarpass
          audio_quality = high
        CFG
        result = resolve(home: home)
        expect([result.username, result.password]).to eq(['me@pianobar.com', 'pianobarpass'])
        expect(result.source).to end_with('pianobar/config')
      end
    end
  end

  describe 'when nothing is found' do
    it 'raises NotFound listing every place it checked' do
      Dir.mktmpdir do |home|
        expect { resolve(home: home) }.to raise_error(described_class::NotFound) do |e|
          expect(e.message).to include('PANDORA_USERNAME')
          expect(e.message).to include('.config/pandoru/credentials.json')
          expect(e.message).to include('.pydora.cfg')
          expect(e.message).to include('pianobar/config')
        end
      end
    end
  end

  def write_creds(path, username, password)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, JSON.generate('username' => username, 'password' => password))
  end
end
