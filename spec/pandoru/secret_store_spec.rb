require 'spec_helper'

RSpec.describe Pandoru::SecretStore do
  # An in-memory adapter for the module-level fetch/store/delete behaviour.
  let(:fake_adapter) do
    Class.new do
      def initialize = @store = {}
      def read(service) = @store[service]
      def write(service, secret) = (@store[service] = secret) && true
      def delete(service) = !@store.delete(service).nil?
      def name = 'fake'
    end.new
  end

  describe '.store / .fetch' do
    it 'round-trips username and password as a single JSON blob' do
      described_class.store('me@x.com', 'pw', adapter: fake_adapter)
      expect(described_class.fetch(adapter: fake_adapter)).to eq(['me@x.com', 'pw'])
    end

    it 'is nil when nothing is stored' do
      expect(described_class.fetch(adapter: fake_adapter)).to be_nil
    end

    it 'is nil on a non-JSON or incomplete blob' do
      fake_adapter.write(described_class::SERVICE, 'garbage')
      expect(described_class.fetch(adapter: fake_adapter)).to be_nil

      fake_adapter.write(described_class::SERVICE, '{"username":"u"}')
      expect(described_class.fetch(adapter: fake_adapter)).to be_nil
    end
  end

  describe 'adapter detection' do
    it 'falls back to the Null adapter when no backend tool is present' do
      runner = ->(_cmd, _stdin) { ['', false] } # `which` fails for everything
      adapter = described_class.adapter(runner: runner)
      expect(adapter).to be_a(described_class::Adapters::Null)
      expect(described_class.available?(adapter: adapter)).to be(false)
    end

    it 'picks the macOS adapter on darwin when security is present', if: RUBY_PLATFORM.include?('darwin') do
      runner = ->(_cmd, _stdin) { ['/usr/bin/security', true] }
      expect(described_class.adapter(runner: runner)).to be_a(described_class::Adapters::MacOS)
    end
  end

  describe described_class::Adapters::MacOS do
    it 'reads with `security find-generic-password -w` and chomps' do
      runner = lambda do |cmd, _stdin|
        cmd == ['security', 'find-generic-password', '-s', 'pandoru', '-w'] ? ["BLOB\n", true] : ['', false]
      end
      expect(described_class.new(runner: runner).read('pandoru')).to eq('BLOB')
    end

    it 'writes with add-generic-password -U carrying the secret' do
      seen = nil
      described_class.new(runner: ->(cmd, _s) { seen = cmd; ['', true] }).write('pandoru', 'BLOB')
      expect(seen).to include('add-generic-password', '-U', '-s', 'pandoru', '-w', 'BLOB')
    end

    it 'returns false when the read fails (no item)' do
      expect(described_class.new(runner: ->(_c, _s) { ['', false] }).read('pandoru')).to be_nil
    end
  end

  describe described_class::Adapters::SecretTool do
    it 'writes by piping the secret to `secret-tool store` over stdin' do
      seen_cmd = nil
      seen_stdin = nil
      runner = ->(cmd, stdin) { seen_cmd = cmd; seen_stdin = stdin; ['', true] }
      described_class.new(runner: runner).write('pandoru', 'BLOB')
      expect(seen_cmd).to eq(['secret-tool', 'store', '--label', 'pandoru', 'service', 'pandoru'])
      expect(seen_stdin).to eq('BLOB')
    end

    it 'reads with `secret-tool lookup`' do
      runner = ->(cmd, _s) { cmd.first(2) == ['secret-tool', 'lookup'] ? ["BLOB\n", true] : ['', false] }
      expect(described_class.new(runner: runner).read('pandoru')).to eq('BLOB')
    end
  end

  describe described_class::Adapters::Windows do
    it 'reports unavailable and no-ops (falls back to file)' do
      adapter = described_class.new
      expect(adapter.available?).to be(false)
      expect(adapter.read('pandoru')).to be_nil
    end
  end
end
