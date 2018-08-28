
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'openstudio-standards/version'

Gem::Specification.new do |spec|
  spec.name          = 'openstudio-standards'
  spec.version       = OpenstudioStandards::VERSION
  spec.authors       = ['Andrew Parker', 'Yixing Chen', 'Mark Adams', 'Kaiyu Sun', 'Mini Maholtra', 'David Goldwasser', 'Phylroy Lopez', 'Maria Mottillo', 'Kamel Haddad', 'Julien Marrec', 'Matt Leach', 'Matt Steen', 'Eric Ringold', 'Daniel Macumber']
  spec.email         = ['andrew.parker@nrel.gov']
  spec.homepage = 'http://openstudio.net'
  spec.summary = 'Creates DOE Prototype building models and transforms proposed OpenStudio models to baseline OpenStudio models.'
  spec.description = 'Creates DOE Prototype building models and transforms proposed models to baseline models for energy codes like ASHRAE 90.1 and the Canadian NECB.'
  spec.license = 'LGPL'

  spec.required_ruby_version = '>= 2.0.0'
  spec.required_rubygems_version = '>= 1.3.6'

  spec.files = Dir['License.txt', 'lib/**/*', 'data/**/*']
  # spec.test_files = Dir['test/**/*']
  spec.require_paths = ['lib']
  spec.add_development_dependency 'minitest-reporters'
  spec.add_development_dependency 'minitest-parallel_fork'
  spec.add_development_dependency 'ruby-progressbar'
  spec.add_development_dependency 'parallel_tests'
  spec.add_development_dependency 'nokogiri', '<= 1.6.8.1'
  spec.add_development_dependency 'bundler', '~> 1.9'
  spec.add_development_dependency 'rake', '~> 10.0'
  spec.add_development_dependency 'yard', '~> 0.9'
  spec.add_development_dependency 'rubocop', '~> 0.53'
  spec.add_development_dependency 'rubocop-checkstyle_formatter', '~> 0.1.1'
  spec.add_development_dependency 'minitest-ci', '<= 5.10.3'
  spec.add_development_dependency 'rubyXL', '3.3.8' # install rubyXL gem to export excel files to json
  spec.add_development_dependency 'activesupport', '4.2.5' # pairs with google-api-client, > 5.0.0 does not work
  spec.add_development_dependency 'google-api-client', '0.8.6' # to download Openstudio_Standards Google Spreadsheet
  spec.add_development_dependency 'codecov' # to perform code coverage checking
  spec.add_development_dependency 'rest-client', '2.0.2'
  spec.add_development_dependency 'aes', '0.5.0'
  spec.add_development_dependency 'roo'
  spec.add_development_dependency 'openstudio-api-stubs'
end
