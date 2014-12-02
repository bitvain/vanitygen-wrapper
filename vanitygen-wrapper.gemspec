# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'vanitygen/version'

Gem::Specification.new do |spec|
  spec.name          = 'vanitygen-wrapper'
  spec.version       = Vanitygen::VERSION
  spec.authors       = ['Benjamin Feng']
  spec.email         = ['contact@fengb.info']
  spec.summary       = %q{Thin ruby wrapper around vanitygen executable}
  spec.description   = %q{Thin ruby wrapper around vanitygen executable. Sibling project of <https://github.com/bitvain/vanitygen-ruby>.}
  spec.homepage      = 'https://github.com/bitvain/vanitygen-wrapper'
  spec.license       = 'MIT'

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.add_runtime_dependency 'mkfifo', '~> 0.0.1'

  spec.add_development_dependency 'bundler', '~> 1.7'
  spec.add_development_dependency 'bitcoin-ruby', '~> 0.0.6'
  spec.add_development_dependency 'ffi', '~> 1.9'
  spec.add_development_dependency 'rake', '~> 10.0'
  spec.add_development_dependency 'rspec', '~> 3.0'
end
