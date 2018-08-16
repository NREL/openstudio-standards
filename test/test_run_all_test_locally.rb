require_relative './helpers/minitest_helper'
require_relative './helpers/create_doe_prototype_helper'
require 'fileutils'
require 'parallel'
require 'open3'

TestListFile = File.join(File.dirname(__FILE__), 'circleci_tests.txt')
TestOutputFolder = File.join(File.dirname(__FILE__), 'local_test_output')
ProcessorsUsed = ( Parallel.processor_count * 2 / 3 ).floor

class String
  # colorization
  def colorize(color_code)
    "\e[#{color_code}m#{self}\e[0m"
  end

  def red
    colorize(31)
  end

  def green
    colorize(32)
  end

  def yellow
    colorize(33)
  end

  def blue
    colorize(34)
  end

  def pink
    colorize(35)
  end

  def light_blue
    colorize(36)
  end
end


def write_results(result, test_file)
  test_result = false
  if result[2].success?
    test_result = true
    puts "PASSED: #{test_file}".green
  else
    test_result = false
    output = {"test" => test_file, "test_result" => test_result, "output" => {"status" => result[2], "std_out" => result[0], "std_err" => result[1]}}
    #puts output
    test_file_output =  File.join(TestOutputFolder, "#{File.basename(test_file)}_test_output.json")
    #puts test_file_output
    File.open(test_file_output, 'w') {|f| f.write(JSON.pretty_generate(output))}
    puts "FAILED: #{test_file_output}".red
  end
end

class RunAllTests< Minitest::Test
  def test_all()
    require_relative './helpers/ci_test_generator'
    CITestGenerator::generate(true)

    @full_file_list = nil
    FileUtils.rm_rf(TestOutputFolder)
    FileUtils.mkpath(TestOutputFolder)

    if File.exist?(TestListFile)
      # load test files from file.
      @full_file_list = File.readlines(TestListFile).shuffle
      # Select only .rb files that exist
      @full_file_list.select! {|item| item.include?('rb') && File.exist?(File.absolute_path("test/#{item.strip}"))}
      @full_file_list.map! {|item| File.absolute_path("test/#{item.strip}")}
    else
      puts "Could not find list of files to test at #{TestListFile}"
      return false
    end

    puts "Running #{@full_file_list.size} tests suites in parallel using #{ProcessorsUsed} of available cpus."
    puts "To increase or decrease the ProcessorsUsed, please edit the test/test_run_all_locally.rb file."
    timings_json = Hash.new()
    Parallel.each(@full_file_list, in_threads: (ProcessorsUsed), progress: "Progress :" ) do |test_file|
      file_name = File.basename(test_file, '.rb')
      timings_json[test_file.to_s] = {}
      timings_json[test_file.to_s]['start'] = Time.now.to_i
      write_results(Open3.capture3('bundle', 'exec', "ruby '#{test_file}'"), test_file)
      timings_json[test_file.to_s]['end'] = Time.now.to_i
      timings_json[test_file.to_s]['total'] =timings_json[test_file.to_s]['end'] - timings_json[test_file.to_s]['start']
    end
    File.open(File.join(File.dirname(__FILE__), 'helpers', 'ci_test_helper', 'timings.json'), 'w') { |file| file.puts(JSON.pretty_generate(timings_json))}
  end

end
