$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'minitest/autorun'
require 'minitest/reporters'
require 'openstudio'
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
