require 'spec_helper'
require 'stringio'

RSpec.describe Pandoru do
  describe '.root' do
    it 'returns a Pathname joined under the gem root' do
      expect(described_class.root).to be_a(Pathname)
      expect(described_class.root('lib', 'pandoru.rb').to_s).to end_with('lib/pandoru.rb')
    end
  end

  describe '.set_logger / .logger' do
    it 'builds a Logger at the requested device and level' do
      io = StringIO.new
      logger = described_class.set_logger(logdev: io, level: Logger::WARN)
      expect(logger).to be_a(Logger)
      expect(logger.level).to eq(Logger::WARN)
    end

    it 'formats every severity (exercises the colour formatter branches)' do
      io = StringIO.new
      logger = described_class.set_logger(logdev: io, level: Logger::DEBUG)
      %i[debug info warn error fatal].each { |level| logger.public_send(level, "msg-#{level}") }
      expect(io.string).to include('msg-debug', 'msg-info', 'msg-warn', 'msg-error', 'msg-fatal')
    end

    it 'memoizes the default logger' do
      expect(described_class.logger).to be(described_class.logger)
    end
  end
end
