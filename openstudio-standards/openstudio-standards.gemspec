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
  
  spec.files = Dir['License.txt', 'lib/**/*', 'data/**/*']
  #spec.test_files = Dir['test/**/*']
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.9"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "yard", "~> 0.8"
  spec.add_development_dependency "rubocop", "~> 0.26"
  spec.add_development_dependency "minitest-reporters"
  spec.add_development_dependency "rubyXL", "3.3.8" # install rubyXL gem to export excel files to json
  spec.add_development_dependency "google-api-client", "0.8.6" # to download Openstudio_Standards Google Spreadsheet
  spec.add_development_dependency "coveralls" # to perform code coverage checking
  
end
