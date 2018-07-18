require_relative './helpers/minitest_helper'
require_relative './helpers/create_doe_prototype_helper'
require 'parallel'
require 'open3'

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

class RunAllTests< Minitest::Test

  def test_all()
    @full_file_list = nil
    @test_list_file = File.join(File.dirname(__FILE__), 'circleci_tests.txt')
    @test_output =    File.join(File.dirname(__FILE__), 'circleci_tests_errors.json')

    if File.exist?(@test_list_file)
      # load test files from file.
      @full_file_list = File.readlines(@test_list_file)
      # Select only .rb files that exist
      @full_file_list.select! {|item| item.include?('rb') && File.exist?(File.absolute_path("test/#{item.strip}"))}
      @full_file_list.map! {|item| File.absolute_path("test/#{item.strip}")}
    else
      puts "Could not find list of files to test at #{@test_list_file}"
      return false
    end
    output = {}
    failures = []
    passed = []
    puts "Running #{@full_file_list.size} tests in parallel using #{Parallel.processor_count- 1} availble threads."
    Parallel.each(@full_file_list, in_threads: (Parallel.processor_count-1)) do |test_file|
      command = "ruby '#{test_file}'"
      stdout_str, stderr_str, status = Open3.capture3('bundle', 'exec', command)
      if status.success?
        puts "#{test_file} passed.".green
        passed << {"test" => test_file, output => {"status"=> status, "std_out" => stdout_str, "std_err" => stderr_str}}
      else
        puts "#{test_file} failed.".red
        failures << {"test" => test_file, output => {"status"=> status, "std_out" => stdout_str, "std_err" => stderr_str}}
      end
    end
    output['failures'] = failures
    output['passed'] = passed
    File.open(@test_output, 'w') {|f| f.write(JSON.pretty_generate(output))}
    assert(failures.size == 0, "\n #{failures.size} tests did not pass \n #{failures.map do |test| test['test'] end} \n Please review the failed output log at #{@test_output}\n".red)
  end
end