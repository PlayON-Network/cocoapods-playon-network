# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'cocoapods-playon-network/gem_version.rb'

Gem::Specification.new do |spec|
  spec.name          = 'cocoapods-playon-network'
  spec.version       = CocoapodsPlayonNetwork::VERSION
  spec.authors       = ['PlayON Network']
  spec.email         = ['devs@playon.network']
  spec.summary       = %q{Setup the PLAYON Network SDK for iOS easily}
  spec.description   = %q{Cocoapods plugin used to setup the PLAYON Network SDK for iOS}
  spec.homepage      = 'https://playon.network'
  spec.license       = 'Apache-2.0'

  spec.files         = Dir['lib/**/*']
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.add_runtime_dependency 'rubyzip', '~> 1'
  spec.add_runtime_dependency 'xcodeproj', '~> 1'
  spec.add_runtime_dependency 'cocoapods-s3', '~> 1'
  spec.add_development_dependency 'bundler', '~> 1.3'
  spec.add_development_dependency 'rake', '~> 1'

  spec.metadata = {
    "documentation_uri" => "https://github.com/PlayON-Network/cocoapods-playon-network",
    "homepage_uri"      => "https://playon.network",
    "source_code_uri"   => "https://github.com/PlayON-Network/cocoapods-playon-network",
  }
end
