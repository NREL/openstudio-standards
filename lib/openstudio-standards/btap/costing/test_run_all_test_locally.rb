
require 'fileutils'
require 'parallel'
require 'open3'
require 'minitest/autorun'
require 'json'
require_relative './parallel_tests'
require_relative './btap_results/tests/BtapResults_test_helper' # Required for the cached switch
TestListFile = File.join(File.dirname(__FILE__), 'test_list.txt')

class RunAllTests < Minitest::Test
  def test_all()
    full_file_list = nil
    if File.exist?(TestListFile)
      puts TestListFile
      # load test files from file.
      full_file_list = File.readlines(TestListFile).shuffle
      # Select only .rb files that exist
      full_file_list.select! {|item| item.include?('rb') && File.exist?(File.absolute_path("#{item.strip}"))}
      full_file_list.map! {|item| File.absolute_path("#{item.strip}")}
    else
      puts "Could not find list of files to test at #{TestListFile}"
      return false
    end
    assert(ParallelTests.new.run(full_file_list), "Some tests failed please ensure all test pass and tests have been updated to reflect the changes you expect before issuing a pull request")
  end
end
