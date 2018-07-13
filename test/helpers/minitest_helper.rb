require 'simplecov'
require 'codecov'

# Get the code coverage in html for local viewing
# and in JSON for CI codecov
if ENV['CI'] == 'true'
  SimpleCov.formatter = SimpleCov::Formatter::Codecov
else
  SimpleCov.formatter = SimpleCov::Formatter::HTMLFormatter
end

# Ignore some of the code in coverage testing
SimpleCov.start do
  add_filter '/.idea/'
  add_filter '/.yardoc/'
  add_filter '/data/'
  add_filter '/doc/'
  add_filter '/docs/'
  add_filter '/pkg/'
  add_filter '/test/'
  add_filter '/hvac_sizing/'
  add_filter 'version'  
end

$LOAD_PATH.unshift File.expand_path('../../../lib', __FILE__)
require 'minitest/autorun'
if ENV['CI'] == 'true'
  require 'minitest/ci'
else
  require 'minitest/reporters'
end

require '/usr/Ruby/openstudio'
require 'openstudio/ruleset/ShowRunnerOutput'
require 'json'
require 'fileutils'

# Require local version instead of installed version for developers
begin
  require_relative '../../lib/openstudio-standards.rb'
  puts 'DEVELOPERS OF OPENSTUDIO-STANDARDS: Requiring code directly instead of using installed gem.  This avoids having to run rake install every time you make a change.' 
rescue LoadError
  require 'openstudio-standards'
  puts 'Using installed openstudio-standards gem.' 
end

# Format test output differently depending on whether running
# on CircleCI, RubyMine, or terminal
if ENV['CI'] == 'true'
  puts "Saving test results to #{Minitest::Ci.report_dir}"
else
  if ENV["RM_INFO"]
    Minitest::Reporters.use! [Minitest::Reporters::RubyMineReporter.new]
  else
    Minitest::Reporters.use! [Minitest::Reporters::SpecReporter.new]
  end
end

