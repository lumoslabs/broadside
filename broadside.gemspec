# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'broadside/version'

Gem::Specification.new do |spec|
  spec.name          = 'broadside'
  spec.version       = Broadside::VERSION
  spec.authors       = ['Matthew Leung', 'Lumos Labs, Inc.']
  spec.email         = ['leung.mattp@gmail.com']

  spec.summary       = 'A command-line tool for EC2 Container Service deployment.'
  spec.homepage      = 'https://github.com/lumoslabs/broadside'
  spec.license       = 'MIT'
  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "bin"
  spec.executables   = ['broadside']
  spec.require_paths = ["lib"]

  spec.add_dependency 'activesupport', '>= 3', '< 5'
  spec.add_dependency 'aws-sdk', '~> 2.3'
  spec.add_dependency 'dotenv', '~> 2.1'
  spec.add_dependency 'gli', '~> 2.13'
  spec.add_dependency 'rainbow', '~> 2.1'

  spec.add_development_dependency 'rspec', '~> 3.4.0'
  spec.add_development_dependency 'bundler', '~> 1.9'
  spec.add_development_dependency 'fakefs'
end
