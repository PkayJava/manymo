# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'manymo/version'

Gem::Specification.new do |spec|
  spec.name          = "manymo"
  spec.version       = Manymo::VERSION
  spec.authors       = ["Pete Schwamb"]
  spec.email         = ["pete@manymo.com"]
  spec.description   = %q{Manymo client tool.}
  spec.summary       = %q{A command line utility for connecting to remote emulators.}
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency 'faye', '~> 1.0.1'
  spec.add_runtime_dependency 'digest-crc'
  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake"
end
