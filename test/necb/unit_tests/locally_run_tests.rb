require_relative '../../helpers/parallel_tests'
TestListFile = Dir.entries("#{__dir__}/tests")


class RunNECBTests < Minitest::Test
  def test_all()
    full_file_list = nil
      # load test files from file.
      full_file_list = TestListFile
    output_folder = File.join(__dir__, 'test_output')
    FileUtils.rm_rf(output_folder)
    FileUtils.mkdir_p(output_folder)

      # Select only .rb files that exist
      full_file_list.select! {|item| item.end_with?(".rb") and File.exist?(File.absolute_path(File.join(__dir__,'tests',"#{item.strip}")))}
      full_file_list = full_file_list.map! {|item| File.absolute_path(File.join(__dir__,'tests',"#{item.strip}")) }
    puts "Starting System Tests"
    assert(ParallelTests.new.run(full_file_list, output_folder), "Some tests failed please ensure all test pass and tests have been updated to reflect the changes you expect before issuing a pull request")
  end
end