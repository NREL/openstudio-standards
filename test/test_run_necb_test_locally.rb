require_relative './parallel_tests'
TestListFile = File.join(File.dirname(__FILE__), 'local_circleci_tests.txt')

class RunNECBTests < Minitest::Test
  def test_all()
    full_file_list = nil
    if File.exist?(TestListFile)
      # load test files from file.
      full_file_list = File.readlines(TestListFile).shuffle
      # Select only .rb files that exist
      full_file_list.select! {|item| item.include?('rb') && item.include?('necb') && File.exist?(File.absolute_path("test/#{item.strip}"))}
      full_file_list.map! {|item| File.absolute_path("test/#{item.strip}")}
    else
      puts "Could not find list of files to test at #{TestListFile}"
      return false
    end
    assert(ParallelTests.new.run(full_file_list), "Some tests failed please ensure all test pass and tests have been updated to reflect the changes you expect before issuing a pull request")
  end
end
