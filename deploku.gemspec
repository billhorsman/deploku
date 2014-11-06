# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'deploku/version'

Gem::Specification.new do |spec|
  spec.name          = "deploku"
  spec.version       = Deploku::VERSION
  spec.authors       = ["Bill Horsman"]
  spec.email         = ["bill@logicalcobwebs.com"]
  spec.summary       = %q{Convenient way of deploying to Heroku}
  spec.homepage      = "https://github.com/billhorsman/deploku"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.7"
  spec.add_development_dependency "rake", "~> 10.0"
end
