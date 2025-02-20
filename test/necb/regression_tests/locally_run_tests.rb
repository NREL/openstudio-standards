require_relative '../../helpers/parallel_tests'
require 'optparse'

class RunNECBTests < Minitest::Test

  # Class variable to store command line options.
  @@options = { all: false, exit: false}

  def self.parse_options
    OptionParser.new do |opts|
      opts.banner = "Usage: locally_run_tests.rb [options]"
      opts.on('-a', '--all', 'All test files in tests folder') { @@options[:all] = true }
      opts.on('-c', '--ci_tests', 'Test files listed in the CI_tests.txt file (default option)') { @@options[:all] = false }
      opts.on('-h', '--help', 'Show help message') do
        puts opts
        @@options[:exit] = true
      end
    end.parse!
  end

  # Wrapper method for the tests.
  def test_all
    exit if @@options[:exit]
    relativeOutputFolder = File.join(__dir__, '/output') # Everything in this folder will be deleted!
    if @@options[:all]

      # Get the files from the tests folder.
      full_file_list = Dir.entries(File.join(__dir__, 'tests')).select do |item|
        item.end_with?(".rb") && File.exist?(File.absolute_path(File.join(__dir__, 'tests', item.strip)))
      end.map do |item|
        File.absolute_path(File.join(__dir__, 'tests', item.strip))
      end
    else
      
      # Get the files from the ci_tests.txt file.
      selected_lines = File.foreach(File.join(__dir__, '../../ci_tests.txt')).select do |line|
        line.start_with?("necb/regression_tests")
      end
      full_file_list = selected_lines.map do |item|
        File.absolute_path(File.join(__dir__, '../..', item.strip))
      end
    end

    puts "Starting #{full_file_list.count} Regression Model Tests"
    assert(ParallelTests.new.run(full_file_list, relativeOutputFolder), "Some tests failed please ensure all test pass and tests have been updated to reflect the changes you expect before issuing a pull request")
  end
end

# Parse options before running tests.
RunNECBTests.parse_options
