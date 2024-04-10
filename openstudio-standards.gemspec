lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'openstudio-standards/version'

Gem::Specification.new do |spec|
  spec.name          = 'openstudio-standards'
  spec.version       = OpenstudioStandards::VERSION
  spec.authors       = ['Andrew Parker', 'Yixing Chen', 'Mark Adams', 'Kaiyu Sun', 'Mini Maholtra', 'David Goldwasser', 'Phylroy Lopez', 'Maria Mottillo', 'Kamel Haddad', 'Julien Marrec', 'Matt Leach', 'Matt Steen', 'Eric Ringold', 'Daniel Macumber', 'Matthew Dahlhausen', 'Jian Zhang', 'Doug Maddox', 'Yunyang Ye', 'Xuechen (Jerry) Lei', 'Juan Gonzalez Matamoros', 'Jeremy Lerond', 'Carlos Duarte']
  spec.email         = ['andrew.parker@nrel.gov']
  spec.homepage = 'http://openstudio.net'
  spec.summary = 'Creates DOE Prototype building models and transforms proposed OpenStudio models to baseline OpenStudio models.'
  spec.description = 'Creates DOE Prototype building models and transforms proposed models to baseline models for energy codes like ASHRAE 90.1 and the Canadian NECB.'
  spec.license = 'Modified BSD License'

  spec.required_ruby_version = '>= 2.0.0'
  spec.required_rubygems_version = '>= 1.3.6'

  spec.files = Dir['LICENSE.md', 'lib/**/*', 'data/**/*']
  # spec.test_files = Dir['test/**/*']
  spec.require_paths = ['lib']
  spec.add_development_dependency 'minitest-reporters', '1.6.1'
  spec.add_development_dependency 'minitest-parallel_fork'
  spec.add_development_dependency 'ruby-progressbar'
  if RUBY_VERSION < '2.3'
    spec.add_development_dependency 'parallel_tests', '<= 2.32.0'
    spec.add_development_dependency 'nokogiri', '<= 1.6.8.1'
    spec.add_development_dependency 'bundler', '~> 1.9'
  elsif RUBY_VERSION < '2.7'
    spec.add_development_dependency 'parallel_tests', '~> 3.0.0'
    spec.add_development_dependency 'nokogiri', '<= 1.11.7' # updated to use more secure version
    spec.add_development_dependency 'bundler', '~> 2.1'
  else
    spec.add_development_dependency 'parallel_tests', '~> 3.7.0'
    spec.add_development_dependency 'nokogiri', '1.15.6'
    spec.add_development_dependency 'bundler', '~> 2.1.4'
  end
  spec.add_development_dependency 'rake', '~> 12.3.1'
  spec.add_development_dependency 'yard', '~> 0.9'
  spec.add_development_dependency 'rubocop', '0.68.1'
  spec.add_development_dependency 'rubocop-checkstyle_formatter', '~> 0.1.1'
  spec.add_development_dependency 'minitest-ci', '<= 5.10.3'
  spec.add_development_dependency 'rubyXL', '~> 3.4'
  spec.add_development_dependency 'google_drive'
  spec.add_development_dependency 'simplecov-html', '< 0.11.0'
  spec.add_development_dependency 'codecov'
  spec.add_development_dependency 'rest-client', '2.0.2'
  spec.add_development_dependency 'aes', '0.5.0'
  spec.add_development_dependency 'roo', '2.7.1'
  spec.add_development_dependency 'openstudio-api-stubs'
  spec.add_runtime_dependency 'tbd', '~> 3'
  spec.add_development_dependency 'aws-sdk-s3'
  spec.add_development_dependency 'git-revision'
end
