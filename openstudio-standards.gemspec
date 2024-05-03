lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'openstudio-standards/version'

Gem::Specification.new do |spec|
  spec.name          = 'openstudio-standards'
  spec.version       = OpenstudioStandards::VERSION
  spec.authors       = ['Mark Adams', 'Yeonjin Bae', 'Carlo Bianchi', 'Jeff Blake', 'Yixing Chen', 'Matthew Dahlhausen', 'Carlos Duarte', 'Sarah Gilani', 'David Goldwasser', 'Kamel Haddad', 'Piljae Im', 'Chris Kirney', 'Matt Leach', 'Xuechen (Jerry) Lei', 'Jeremy Lerond', 'Nicholas Long', 'Phylroy Lopez', 'Iain MacDonald', 'Daniel Macumber', 'Doug Maddox', 'Mini Maholtra', 'Julien Marrec', 'Juan Gonzalez Matamoros', 'Maria Mottillo', 'Andrew Parker', 'Padmassun Rajakareyar', 'Eric Ringold', 'Matt Steen', 'Kaiyu Sun', 'Weilie Xu', 'Yunyang Ye', 'Jian Zhang']
  spec.email         = ['matthew.dahlhausen@nrel.gov']
  spec.homepage      = 'http://openstudio.net'
  spec.summary       = 'Creates OpenStudio models of typical buildings, creates standard baselines from proposed models, and checks a model against a standard.'
  spec.description   = 'The openstudio-standards library provides methods for programatically generating, modifying, and checking OpenStudio building energy models. It can create a typical building from user geometry, template geometry, or programmatically generated geometry. It can apply a building standard including ASHRAE 90.1 or NECB to a model. It can transform a proposed building model into a 90.1 Appendix G code baseline model. It can check a model against a building standard. It can generate represenative typical buildings, such as those used in ComStock.'
  spec.license       = 'Modified BSD License'

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
  elsif RUBY_VERSION < '3.2'
    spec.add_development_dependency 'parallel_tests', '~> 3.7.0'
    spec.add_development_dependency 'nokogiri', '~> 1.11'
    spec.add_development_dependency 'bundler', '~> 2.1.4'
  else
    spec.add_development_dependency 'parallel_tests', '~> 3.7.0'
    spec.add_development_dependency 'nokogiri', '~> 1.16'
    spec.add_development_dependency 'bundler', '~> 2.4.10'
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
  # spec.add_development_dependency 'aws-sdk-s3'
  # spec.add_development_dependency 'git-revision'
end
