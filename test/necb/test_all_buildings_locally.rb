
require_relative '../helpers/minitest_helper'
require_relative '../helpers/create_doe_prototype_helper'
require_relative '../helpers/compare_models_helper'
require 'minitest/parallel_fork'

Dir["#{File.dirname(__FILE__)}/test_necb_bldg*.rb"].each do |test|
  require_relative File.basename(test)
end




