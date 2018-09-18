require_relative '../helpers/minitest_helper'
require_relative '../helpers/create_doe_prototype_helper'
require 'fileutils'
require 'parallel'
require 'open3'

ProcessorsUsed = (Parallel.processor_count * 2 / 3).floor
TestOutputFolder = File.join(File.dirname(__FILE__), 'regression_test_output')

def write_results(result, test_file)
  test_file_output = File.join(TestOutputFolder, "#{File.basename(test_file)}_test_output.json")
  File.delete(test_file_output) if File.exist?(test_file_output)
  test_result = false
  if result[2].success?
    puts "PASSED: #{test_file}".green
    return true
  else
    #store output for failed run.
    output = {"test" => test_file,
              "test_result" => test_result,
              "output" => {
                  "status" => result[2],
                  "std_out" => result[0].split(/\r?\n/),
                  "std_err" => result[1].split(/\r?\n/)
              }
    }


    #puts test_file_output
    File.open(test_file_output, 'w') {|f| f.write(JSON.pretty_generate(output))}
    puts "FAILED: #{test_file_output}".red
    return false
  end
end


class RunAllTests < Minitest::Test

  def test_all()
    did_all_tests_pass = true
    require_relative './helpers/ci_test_generator'
    CITestGenerator::generate(true)

    @full_file_list = nil
    FileUtils.rm_rf(TestOutputFolder)
    FileUtils.mkpath(TestOutputFolder)


    # load test files from file.
    @full_file_list = Dir[File.join(File.dirname(__FILE__), '..', 'ci_test_files', 'test_necb_bldg_*.rb')].shuffle
    # Select only .rb files that exist
    @full_file_list.select! {|item| item.include?('rb') && File.exist?(File.absolute_path("test/#{item.strip}"))}
    @full_file_list.map! {|item| File.absolute_path("test/#{item.strip}")}


    puts "Running #{@full_file_list.size} tests suites in parallel using #{ProcessorsUsed} of available cpus."
    puts "To increase or decrease the ProcessorsUsed, please edit the test/test_run_all_locally.rb file."
    timings_json = Hash.new()
    Parallel.each(@full_file_list, in_threads: (ProcessorsUsed), progress: "Progress :".blue) do |test_file|
      file_name = test_file.gsub(/^.+(openstudio-standards\/test\/)/, '')
      timings_json[file_name.to_s] = {}
      timings_json[file_name.to_s]['start'] = Time.now.to_i
      did_all_tests_pass = false unless write_results(Open3.capture3('bundle', 'exec', "ruby '#{test_file}'"), test_file)
      timings_json[file_name.to_s]['end'] = Time.now.to_i
      timings_json[file_name.to_s]['total'] = timings_json[file_name.to_s]['end'] - timings_json[file_name.to_s]['start']
    end
    #Sometimes the runs fail.
    #Load failed JSON files from folder local_test_output
    unless did_all_tests_pass
      did_all_tests_pass = true
      failed_runs = []
      files = Dir.glob("#{File.dirname(__FILE__)}/local_test_output/*.json").select {|e| File.file? e}
      files.each do |file|
        data = JSON.parse(File.read(file))
        failed_runs << data["test"]
      end
      puts "These files failed in the initial simulation. This may have been due to computer performance issues. Rerunning failed tests.."
      Parallel.each(failed_runs, in_threads: (ProcessorsUsed), progress: "Progress :") do |test_file|
        file_name = test_file.gsub(/^.+(openstudio-standards\/test\/)/, '')
        timings_json[file_name.to_s] = {}
        timings_json[file_name.to_s]['start'] = Time.now.to_i
        did_all_tests_pass = false unless write_results(Open3.capture3('bundle', 'exec', "ruby '#{test_file}'"), test_file)
        timings_json[file_name.to_s]['end'] = Time.now.to_i
        timings_json[file_name.to_s]['total'] = timings_json[file_name.to_s]['end'] - timings_json[file_name.to_s]['start']
      end
    end

    File.open(File.join(File.dirname(__FILE__), 'helpers', 'ci_test_helper', 'timings.json'), 'w') {|file| file.puts(JSON.pretty_generate(timings_json.sort {|a, z| a <=> z}.to_h))}
    assert(did_all_tests_pass, "Some tests failed please ensure all test pass and tests have been updated to reflect the changes you expect before issuing a pull request")
  end


  def test_all_necg_bldg_regression()
    require_relative '../helpers/ci_test_generator'
    CITestGenerator::generate(true)
    puts "=" * 30
    full_file_list = Dir[File.join(File.dirname(__FILE__), '..', 'ci_test_files', 'test_necb_bldg_*.rb')]
    puts full_file_list
    puts "Running #{full_file_list.size} tests suites in parallel using #{ProcessorsUsed} of available cpus."
    puts "To increase or decrease the ProcessorsUsed, please edit the test/test_run_all_locally.rb file."
    Parallel.each(full_file_list, in_threads: (ProcessorsUsed), progress: "Progress :") do |test_file|
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
