require_relative '../../helpers/parallel_tests'

class RunNECBTests < Minitest::Test
  def test_all()
    full_file_list = Dir.entries(File.join(__dir__, 'tests'))
    relativeOutputFolder = File.join(__dir__, '/output') # Everything in this folder will be deleted!
    
    # The file list will contain '.' and '..' as entries. Remove these and any other non-existent entries. Then map the file names to a full path.
    full_file_list.select! {|item| item.end_with?(".rb") and File.exist?(File.absolute_path(File.join(__dir__, 'tests', "#{item.strip}")))}
    full_file_list = full_file_list.map! {|item| File.absolute_path(File.join(__dir__, 'tests', "#{item.strip}"))}
    puts "Starting #{full_file_list.count} Unit Tests"
    assert(ParallelTests.new.run(full_file_list, relativeOutputFolder), "Some tests failed please ensure all test pass and tests have been updated to reflect the changes you expect before issuing a pull request")
  end
end