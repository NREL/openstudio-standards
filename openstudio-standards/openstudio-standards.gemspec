# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'openstudio-standards/version'

Gem::Specification.new do |spec|
  spec.name          = "openstudio-standards"
  spec.version       = OpenstudioStandards::VERSION
  spec.authors       = ["Andrew Parker","Yixing Chen", "Mark Adams", "Kaiyu Sun", "Mini Maholtra", "David Goldwasser", "Phylroy Lopez", "Maria Mottillo", "Kamel Haddad"]
  spec.email         = ["andrew.parker@nrel.gov"]
  spec.homepage = 'http://openstudio.net'
  spec.summary = 'Applies energy standards like ASHRAE 90.1 and the Canadian NECB to OpenStudio energy models'
  spec.description = 'Custom classes for configuring clusters for OpenStudio & EnergyPlus analyses'
  spec.license = 'LGPL'

  spec.required_ruby_version = '>= 2.0.0'
  spec.required_rubygems_version = '>= 1.3.6'  
  
  #spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  #spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.9"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "yard", "~> 0.8"
  spec.add_development_dependency "rubocop", "~> 0.26"
  spec.add_development_dependency "minitest-reporters"
  spec.add_development_dependency "rubyXL", "~> 3.3.0" # install rubyXL gem to export excel files to json
  
end
