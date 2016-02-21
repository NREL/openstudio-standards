$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'minitest/autorun'
require 'minitest/reporters'
require 'openstudio'
require 'simplecov'
require 'coveralls'

# Ignore some of the code in coverage testing
SimpleCov.formatter = Coveralls::SimpleCov::Formatter
SimpleCov.start do
  add_filter '/.idea/'
  add_filter '/.yardoc/'
  add_filter '/data/'
  add_filter '/doc/'
  add_filter '/docs/'
  add_filter '/pkg/'
  add_filter '/test/'
end

Coveralls.wear!
# Require local version instead of installed version for developers
if require_relative '../lib/openstudio-standards.rb'
  puts 'DEVELOPERS OF OPENSTUDIO-STANDARDS: Requiring code directly instead of using installed gem.  This avoids having to run rake install every time you make a change.' 
else
  require 'openstudio-standards'
end
require 'openstudio/ruleset/ShowRunnerOutput'
require 'json'
require 'fileutils'

Minitest::Reporters.use! Minitest::Reporters::SpecReporter.new # spec-like progress
