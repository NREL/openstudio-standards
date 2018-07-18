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
    @test_output = File.join(File.dirname(__FILE__))

    if File.exist?(@test_list_file)
      # load test files from file.
      @full_file_list = File.readlines(@test_list_file).shuffle
      # Select only .rb files that exist
      @full_file_list.select! {|item| item.include?('rb') && File.exist?(File.absolute_path("test/#{item.strip}"))}
      @full_file_list.map! {|item| File.absolute_path("test/#{item.strip}")}
    else
      puts "Could not find list of files to test at #{@test_list_file}"
      return false
    end
    processors_used = ((Parallel.processor_count) - 6).round
    output = {}
    failures = []
    passed = []
    puts "Running #{@full_file_list.size} tests suites in parallel using #{processors_used} which is 2/3 of available cpus."
    puts "To increase or decrease the processors_used, please edit the test/test_run_all_locally.rb file."
    Parallel.each(@full_file_list, in_processes: (processors_used)) do |test_file|
      command = "ruby '#{test_file}'"
      stdout_str, stderr_str, status = Open3.capture3('bundle', 'exec', command)
      test_result = false
      if status.success?
        test_result = true
        puts "#{test_file} passed.".green
      else
        test_result = false
        puts "#{test_file} failed.".red
      end
      output = {"test" => test_file, "test_result" => test_result, "output" => {"status" => status, "std_out" => stdout_str, "std_err" => stderr_str}}
      @test_file_output = File.join(File.dirname(__FILE__), "#{test_file}_test_output.json")
      File.open(@test_file_output, 'w') {|f| f.write(JSON.pretty_generate(output))}
    end
  end
end
