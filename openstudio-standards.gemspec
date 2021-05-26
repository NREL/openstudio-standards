
### Loads OpenStudio here instead of what is installed locally on PC
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'openstudio-standards/version'

Gem::Specification.new do |spec|
  spec.name          = 'openstudio-standards'
  spec.version       = OpenstudioStandards::VERSION
  spec.authors       = ['Andrew Parker', 'Yixing Chen', 'Mark Adams', 'Kaiyu Sun', 'Mini Maholtra', 'David Goldwasser', 'Phylroy Lopez', 'Maria Mottillo', 'Kamel Haddad', 'Julien Marrec', 'Matt Leach', 'Matt Steen', 'Eric Ringold', 'Daniel Macumber', 'Matthew Dahlhausen']
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
  if RUBY_VERSION < '2.3'
    spec.add_development_dependency 'parallel_tests', '<= 2.32.0'
    spec.add_development_dependency 'nokogiri', '<= 1.6.8.1'
    spec.add_development_dependency 'bundler', '~> 1.9'
  elsif RUBY_VERSION < '2.7'
    spec.add_development_dependency 'parallel_tests', '~> 3.0.0'
    spec.add_development_dependency 'nokogiri', '<= 1.8.2'
    spec.add_development_dependency 'bundler', '~> 2.1'
  else
    spec.add_development_dependency 'parallel_tests', '~> 3.0.0'
    spec.add_development_dependency 'nokogiri', '<= 1.11.5'
    spec.add_development_dependency 'bundler', '~> 2.1'
  end
  spec.add_development_dependency 'rake', '~> 12.3.1'
  spec.add_development_dependency 'yard', '~> 0.9'
  spec.add_development_dependency 'rubocop', '0.68.1'
  spec.add_development_dependency 'rubocop-checkstyle_formatter', '~> 0.1.1'
  spec.add_development_dependency 'minitest-ci', '<= 5.10.3'
  spec.add_development_dependency 'rubyXL', '3.4.17' # install rubyXL gem to export excel files to json
  spec.add_development_dependency 'activesupport', '4.2.5' # pairs with google-api-client, > 5.0.0 does not work
  spec.add_development_dependency 'public_suffix', '3.0.3' # fixing version of google-api-client dependency
  spec.add_development_dependency 'faraday', '0.15.4' # fixing version of google-api-client dependency
  spec.add_development_dependency 'signet', '< 0.12.0' # development dependency for google-api-client
  spec.add_development_dependency 'launchy', '< 2.5.0' # development dependency for google-api-client
  spec.add_development_dependency 'google-api-client', '0.8.6' # to download Openstudio_Standards Google Spreadsheet
  spec.add_development_dependency 'simplecov-html', '< 0.11.0'
  spec.add_development_dependency 'codecov' # to perform code coverage checking
  spec.add_development_dependency 'rest-client', '2.0.2'
  spec.add_development_dependency 'aes', '0.5.0'
  spec.add_development_dependency 'roo', '2.7.1'
  spec.add_development_dependency 'openstudio-api-stubs'
end
