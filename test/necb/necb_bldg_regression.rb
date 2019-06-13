require_relative '../helpers/minitest_helper'
require_relative '../helpers/create_doe_prototype_helper'
require 'fileutils'
require 'parallel'
require 'open3'

ProcessorsUsed = ( Parallel.processor_count * 2 / 3 ).floor
TestOutputFolder = File.join(File.dirname(__FILE__), 'regression_test_output')

class RunAllTests< Minitest::Test
  def write_results(result, test_file)
    test_result = false
    if result[2].success?
      test_result = true
      puts "PASSED: #{test_file}".green
      assert(test_result,"PASSED: #{test_file}")
    else
      test_result = false
      output = {"test" => test_file, "test_result" => test_result, "output" => {"status" => result[2], "std_out" => result[0], "std_err" => result[1]}}
      #puts output
      test_file_output =  File.join(TestOutputFolder, "#{File.basename(test_file)}_test_output.json")
      #puts test_file_output
      File.open(test_file_output, 'w') {|f| f.write(JSON.pretty_generate(output))}
      puts "FAILED: #{test_file_output}".red
      assert(test_result,"FAILED: #{test_file_output}")
    end
  end

  def test_all_bldg_regression()
    require_relative '../helpers/ci_test_generator'
    CITestGenerator::generate(true)
    puts "="*30
    full_file_list = Dir[File.join(File.dirname(__FILE__), '..', 'ci_test_files', 'test_necb_bldg_*.rb')]
    puts full_file_list
    puts "Running #{full_file_list.size} tests suites in parallel using #{ProcessorsUsed} of available cpus."
    puts "To increase or decrease the ProcessorsUsed, please edit the test/test_run_all_locally.rb file."
    Parallel.each(full_file_list, in_threads: (ProcessorsUsed), progress: "Progress :" ) do |test_file|
      # Open3.capture3('bundle', 'exec', "ruby '#{test_file}'")
      write_results(Open3.capture3('bundle', 'exec', "ruby '#{test_file}'"), test_file)
    end
    puts "Check [#{TestOutputFolder}] folder for output".cyan
  end
end

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

  def cyan
    colorize(36)
  end
end