lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "pandoru/version"

Gem::Specification.new do |spec|
  spec.name          = "pandoru"
  spec.version       = Pandoru::VERSION
  spec.authors       = ["Dale Stevens"]
  spec.email         = ["dale@twilightcoders.net"]

  spec.summary       = %q{Ruby client for the Pandora API - unofficial port of pydora}
  spec.description   = %q{A comprehensive Ruby client for the Pandora music streaming API, providing access to stations, playlists, search, and user management features.}
  spec.homepage      = "https://github.com/TwilightCoders/pandoru"
  spec.license       = "MIT"

  if spec.respond_to?(:metadata)
    spec.metadata['allowed_push_host'] = 'https://rubygems.org'
  else
    raise 'RubyGems 2.0 or newer is required to protect against public gem pushes.'
  end

  spec.files         = Dir['CHANGELOG.md', 'README.md', 'LICENSE', 'lib/**/*']
  spec.bindir        = 'bin'
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.required_ruby_version = '>= 3.0'

  # HTTP and networking
  spec.add_runtime_dependency 'faraday', '~> 2.0'
  spec.add_runtime_dependency 'faraday-retry', '~> 2.0'
  
  # Encryption
  spec.add_runtime_dependency 'crypt', '~> 2.2'
  
  # JSON parsing
  spec.add_runtime_dependency 'json', '~> 2.0'

  # base64 was removed from Ruby's default gems in 3.4; transport.rb requires it
  spec.add_runtime_dependency 'base64', '~> 0.2'

  # Development dependencies
  spec.add_development_dependency 'bundler', '~> 2.0'
  spec.add_development_dependency 'rake', '~> 13.0'
  spec.add_development_dependency 'rspec', '~> 3.0'
  spec.add_development_dependency 'webmock', '~> 3.0'
  spec.add_development_dependency 'pry-byebug'
  spec.add_development_dependency 'vcr', '~> 6.0'

  # Coverage (emitted as lcov for Qlty Cloud; only active when COVERAGE is set)
  spec.add_development_dependency 'simplecov', '~> 0.22'
  spec.add_development_dependency 'simplecov-lcov', '~> 0.8'
end
