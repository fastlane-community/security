# frozen_string_literal: true

require_relative 'lib/security/version'

Gem::Specification.new do |s|
  s.name        = 'security'
  s.authors     = ['Josh Holtz', 'Mattt', 'iBotPeaches']
  s.email       = 'me@joshholtz.com'
  s.homepage    = 'https://github.com/fastlane-community/security'
  s.version     = Security::VERSION
  s.platform    = Gem::Platform::RUBY
  s.license     = 'MIT'
  s.summary     = 'Interact with the macOS Keychain'

  s.files         = Dir['./**/*'].grep_v(%r{\./(bin|log|pkg|script|spec|test|vendor)})
  s.executables   = `git ls-files -- bin/*`.split("\n").map { |f| File.basename(f) }
  s.require_paths = ['lib']
  s.required_ruby_version = '>= 3.1.0'

  s.metadata['rubygems_mfa_required'] = 'true'
end
