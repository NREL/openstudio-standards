require 'bundler/gem_tasks'
require 'json'
require 'fileutils'
begin
  Bundler.setup
rescue Bundler::BundlerError => e
  warn e.message
  warn 'Run `bundle install` to install missing gems'
  exit e.status_code
end

require 'rake/testtask'
namespace :test do
  full_file_list = nil
  if File.exist?('test/circleci_tests.txt')
    # load test files from file.
    full_file_list = FileList.new(File.readlines('test/circleci_tests.txt'))
    # Select only .rb files that exist
    full_file_list.select! { |item| item.include?('rb') && File.exist?(File.absolute_path("test/#{item.strip}")) }
    full_file_list.map! { |item| File.absolute_path("test/#{item.strip}") }
    File.open('test/circleci_tests.json', 'w') do |f|
      f.write(JSON.pretty_generate(full_file_list.to_a))
    end
  else
    puts 'Could not find list of files to test at test/circleci_tests.txt'
    return false
  end

  desc 'parallel_run_all_tests_locally'
  Rake::TestTask.new('parallel_run_all_tests_locally') do |t|
    # Make an empty test/reports directory
    report_dir = 'test/reports'
    FileUtils.rm_rf(report_dir) if Dir.exist?(report_dir)
    Dir.mkdir(report_dir)
    file_list = FileList.new('test/parallel_run_all_tests_locally.rb')
    t.libs << 'test'
    t.test_files = file_list
    t.verbose = false
  end

  desc 'parallel_run_necb_building_regression_tests'
  Rake::TestTask.new('parallel_run_necb_building_regression_tests_locally') do |t|
    file_list = FileList.new('test/necb/building_regression_tests/locally_run_tests.rb')
    t.libs << 'test'
    t.test_files = file_list
    t.verbose = false
  end

  desc 'parallel_run_necb_system_tests_tests'
  Rake::TestTask.new('parallel_run_necb_system_tests_tests_locally') do |t|
    file_list = FileList.new('test/necb/system_tests/locally_run_tests.rb')
    t.libs << 'test'
    t.test_files = file_list
    t.verbose = false
  end

  # These tests only available in the CI environment
  if ENV['CI'] == 'true'

    desc 'Run CircleCI tests'
    Rake::TestTask.new('circleci') do |t|
      # Create a FileList for this task
      test_list = FileList.new
      # Read the parallelized list of tests
      # created by the circleci CLI in config.yml
      if File.exist?('node_tests.txt')
        File.open('node_tests.txt', 'r') do |f|
          f.each_line do |line|
            # Skip comments the CLI may have included
            next unless line.include?('.rb')

            # Remove whitespaces
            line = line.strip
            # Ensure the file exists
            pth = File.absolute_path("test/#{line}")
            unless File.exist?(pth)
              puts "Skipped #{line} because this file doesn't exist"
              next
            end
            # Add this test to the list
            test_list.add(pth)
          end
        end
        # Assign the tests to this task
        t.test_files = test_list
      else
        puts 'Could not find parallelized list of CI tests.'
      end
    end

    desc 'Summarize the test timing'
    task 'times' do |t|
      require 'nokogiri'

      files_to_times = {}
      tests_to_times = {}
      Dir['test/reports/*.xml'].each do |xml|
        doc = File.open(xml) { |f| Nokogiri::XML(f) }
        doc.css('testcase').each do |testcase|
          time = testcase.attr('time').to_f
          file = testcase.attr('file')
          name = testcase.attr('name')
          # Add to total for this file
          if files_to_times[file].nil?
            files_to_times[file] = time
          else
            files_to_times[file] += time
          end
          # Record for this test itself
          if tests_to_times[name].nil?
            tests_to_times[name] = time
          else
            tests_to_times[name] += time
          end
        end
      end

      # Write out the test results to file
      folder = "#{Dir.pwd}/timing"
      Dir.mkdir(folder) unless File.exist?(folder)

      # By file
      File.open("#{Dir.pwd}/timing/test_by_file.html", 'w') do |html|
        html.puts '<table><tr><th>File Name</th><th>Time (min)</th></tr>'
        files_to_times.each do |f, time_s|
          s = (time_s / 60).round(1) # convert time from sec to min
          html.puts "<tr><td>#{f}</td><td>#{s}</td></tr>"
        end
        html.puts '</table>'
      end

      # By name
      File.open("#{Dir.pwd}/timing/test_by_name.html", 'w') do |html|
        html.puts '<table><tr><th>Test Name</th><th>Time (min)</th></tr>'
        tests_to_times.each do |f, time_s|
          s = (time_s / 60).round(1) # convert time from sec to min
          html.puts "<tr><td>#{f}</td><td>#{s}</td></tr>"
        end
        html.puts '</table>'
      end
    end

  end
end

# Tasks to manage the spreadsheet data
namespace :data do
  require "#{File.dirname(__FILE__)}/data/standards/manage_OpenStudio_Standards.rb"

  # OpenStudio Standards spreadsheet names
  # Order matters: most general/shared must be first,
  # as data may be overwritten when parsing later spreadsheets.
  spreadsheets_ashrae = [
      'OpenStudio_Standards-ashrae_90_1',
      'OpenStudio_Standards-ashrae_90_1(space_types)',
      'OpenStudio_Standards-ashrae_90_1(speed)'
  ]

  spreadsheets_speed = [
      'OpenStudio_Standards-speed(schedules)'
  ]

  spreadsheets_deer = [
    'OpenStudio_Standards-deer',
    'OpenStudio_Standards-deer(space_types)'
  ]

  spreadsheets_comstock = [
    'OpenStudio_Standards-ashrae_90_1',
    'OpenStudio_Standards-ashrae_90_1-ALL-comstock(space_types)',
    'OpenStudio_Standards-deer',
    'OpenStudio_Standards-deer-ALL-comstock(space_types)'
  ]

  spreadsheets_cbes = [
    'OpenStudio_Standards-cbes',
    'OpenStudio_Standards-cbes(space_types)'
  ]

  spreadsheet_titles = spreadsheets_ashrae + spreadsheets_speed + spreadsheets_deer + spreadsheets_comstock + spreadsheets_cbes
  spreadsheet_titles = spreadsheet_titles.uniq

  desc 'Download all OpenStudio_Standards spreadsheets from Google & export JSONs'
  task 'update' do
    download_google_spreadsheets(spreadsheet_titles)
    export_spreadsheet_to_json(spreadsheet_titles)
  end

  desc 'Export JSONs from OpenStudio_Standards'
  task 'update:manual' do
    # reads data from data/standards/OpenStudio_Standards-speed(schedules).xlsx
    # exports data from sheet 'Schedules' to lib/openstudio-standards/standards/speed/data/speed.schedules.json
    export_spreadsheet_to_json(spreadsheet_titles)
  end

  desc 'Export JSONs from OpenStudio_Standards to data library'
  task 'export:jsons' do
    export_spreadsheet_to_json(spreadsheets_ashrae, dataset_type: 'data_lib')
  end
end

# Tasks to export libraries packaged with
# the OpenStudio installer
namespace :library do
  require "#{File.dirname(__FILE__)}/data/standards/export_OpenStudio_libraries.rb"

  #desc 'Export libraries for OpenStudio installer'
  #task 'export' do
  #  export_openstudio_libraries
  #end

  task 'export_speed_schedules' => ['data:update:manual'] do
    # reads data from lib/openstudio-standards/standards/speed/data/speed.schedules.json
    # exports OSM to data/standards/SpeedSchedules.osm
    model = OpenStudio::Model::Model.new

    std = Standard.build('Speed')

    names = std.standards_data['schedules'].map {|sch| sch['name']}
    names.uniq.each do |name|
      sch = std.model_add_schedule(model, name)
    end

    model.save("#{File.dirname(__FILE__)}/data/standards/SpeedSchedules.osm", true)
  end

  task 'export_speed_constructions' do
    # reads data from lib/openstudio-standards/standards/ashrae_90_1/data/*json
    # exports JSON to data/standards/construction_inputs_new.json
    # exports OSM to data/standards/SpeedConstructions.osm
    require "#{File.dirname(__FILE__)}/data/standards/export_speed_constructions.rb"
  end

  task 'export_speed_space_loads' do
    # reads data from data/standards/InputJSONData_SpaceLoads.csv
    # exports JSON to data/standards/space_loads_inputs_new.json
    require "#{File.dirname(__FILE__)}/data/standards/export_speed_space_loads.rb"
  end

  task 'export_speed_other' do
    # reads data from data/standards/InputJSONData.xlsx
    # exports JSON to data/standards/other_inputs_new.json
    require "#{File.dirname(__FILE__)}/data/standards/export_speed_other.rb"
  end

  task 'export_speed' => ['export_speed_schedules', 'export_speed_constructions', 'export_speed_space_loads', 'export_speed_other'] do
    # reads JSON from data/standards/construction_inputs_new.json
    # reads JSON from data/standards/space_loads_inputs_new.json
    # reads JSON from data/standards/other_inputs_new.json
    # exports JSON to data/standards/inputs_new.json
    require "#{File.dirname(__FILE__)}/data/standards/export_speed.rb"
  end
end

require 'yard'
desc 'Generate the documentation'
YARD::Rake::YardocTask.new(:doc) do |t|
  require_relative 'lib/openstudio-standards/prototypes/common/prototype_metaprogramming.rb'
  # Generate temporary building type class files so that
  # the documentation shows these classes
  save_meta_classes_to_file
  t.stats_options = ['--list-undoc']
end

desc 'Show the documentation in a web browser'
task 'doc:show' => [:doc] do
  link = "#{Dir.pwd}/doc/index.html"
  if RbConfig::CONFIG['host_os'] =~ /mswin|mingw|cygwin/
    system "start #{link}"
  elsif RbConfig::CONFIG['host_os'] =~ /darwin/
    system "open #{link}"
  elsif RbConfig::CONFIG['host_os'] =~ /linux|bsd/
    system "xdg-open #{link}"
  end
  # Remove the generated temporary files
  remove_meta_class_file
end

require 'rubocop/rake_task'
desc 'Check the code for style consistency'
RuboCop::RakeTask.new(:rubocop) do |t|
  # Make a folder for the output
  out_dir = '.rubocop'
  Dir.mkdir(out_dir) unless File.exist?(out_dir)
  # Output both XML (CheckStyle format) and HTML
  t.options = ["--out=#{out_dir}/rubocop-results.xml", '--format=h', "--out=#{out_dir}/rubocop-results.html", '--format=offenses', "--out=#{out_dir}/rubocop-summary.txt"]
  t.requires = ['rubocop/formatter/checkstyle_formatter']
  t.formatters = ['RuboCop::Formatter::CheckstyleFormatter']
  # don't abort rake on failure
  t.fail_on_error = false
end

desc 'Show the rubocop output in a web browser'
task 'rubocop:show' => [:rubocop] do
  link = "#{Dir.pwd}/.rubocop/rubocop-results.html"
  if RbConfig::CONFIG['host_os'] =~ /mswin|mingw|cygwin/
    system "start #{link}"
  elsif RbConfig::CONFIG['host_os'] =~ /darwin/
    system "open #{link}"
  elsif RbConfig::CONFIG['host_os'] =~ /linux|bsd/
    system "xdg-open #{link}"
  end
end
