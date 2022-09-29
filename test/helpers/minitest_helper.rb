=begin
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
=end

$LOAD_PATH.unshift File.expand_path('../../../lib', __FILE__)
require 'minitest/autorun'
if ENV['CI'] == 'true'
  require 'minitest/ci'
  puts "Saving test results to #{Minitest::Ci.report_dir}"
end
require 'minitest/reporters'

require 'openstudio'
require 'openstudio/measure/ShowRunnerOutput'
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

# Set the output reporting format based on the run environment
if ENV['RM_INFO'] || ENV['TEAMCITY_RAKE_RUNNER_MODE'] # RubyMine
  puts "Running tests from RubyMine, using RubyMine test reporter."
  ENV.delete('RM_INFO') # Delete this environment variable because it forces use of only RubyMineReporter
  Minitest::Reporters.use! [Minitest::Reporters::RubyMineReporter.new]
  # line below for PNNL local testing
  # Minitest::Reporters.use! [Minitest::Reporters::RubyMineReporter.new, Minitest::Reporters::JUnitReporter.new(reports_dir="test/reports", empty=false)] 
elsif ENV['JENKINS_HOME'] # Jenkins
  puts "Running tests from Jenkins, using JUnit XML test reporter and console-based test reporter."
  Minitest::Reporters.use! [Minitest::Reporters::SpecReporter.new, Minitest::Reporters::JUnitReporter.new(reports_dir = "test/reports", empty = false)]
else # Terminal or other
  puts "Running tests from terminal, using console-based test reporter."
  Minitest::Reporters.use! [Minitest::Reporters::SpecReporter.new]
  # line below for PNNL local testing
  # Minitest::Reporters.use! [Minitest::Reporters::SpecReporter.new, Minitest::Reporters::JUnitReporter.new(reports_dir="test/reports", empty=false)] 
end
