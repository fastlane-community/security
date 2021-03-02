# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "security"

Gem::Specification.new do |s|
  s.name        = "security"
  s.authors     = ["Mattt"]
  s.email       = "mattt@me.com"
  s.homepage    = "https://mat.tt/"
  s.version     = Security::VERSION
  s.platform    = Gem::Platform::RUBY
  s.license     = "MIT"
  s.summary     = "Interact with the macOS Keychain"

  s.add_development_dependency 'rake', '~> 12.3', '>= 12.3.3'

  s.files         = Dir["./**/*"].reject { |file| file =~ /\.\/(bin|log|pkg|script|spec|test|vendor)/ }
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]
end
