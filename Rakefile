require 'bundler/gem_tasks'
require 'json'
begin
  Bundler.setup
rescue Bundler::BundlerError => e
  $stderr.puts e.message
  $stderr.puts 'Run `bundle install` to install missing gems'
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
    File.open("test/circleci_tests.json","w") do |f|
      f.write(JSON.pretty_generate(full_file_list.to_a))
    end
  else
    puts 'Could not find list of files to test at test/circleci_tests.txt'
    return false
  end


  desc 'Run All CircleCI tests'
  Rake::TestTask.new('local-circ-all-tests') do |t|
    file_list = FileList.new('test/helpers/ci_test_generator.rb', 'test/test_run_all_test_locally.rb')
    t.libs << 'test'
    t.test_files = file_list
    t.verbose = false
  end

  desc 'Generate CircleCI test files'
  Rake::TestTask.new('gen-circ-files') do |t|
    file_list = FileList.new('test/helpers/ci_test_generator.rb')
    t.libs << 'test'
    t.test_files = file_list
    t.verbose = false
  end


  desc 'Run BTAP.perform_qaqc() test'
  Rake::TestTask.new(:btap_json_test) do |t|
    file_list = FileList.new('test/necb/test_necb_qaqc.rb')
    t.libs << 'test'
    t.test_files = file_list
    t.verbose = true
  end

  ['90_1_prm', '90_1_general', 'doe_prototype', 'necb', 'necb_bldg'].each do |type|
    desc "Manual Run CircleCI tests #{type}"
    Rake::TestTask.new("circ-#{type}") do |t|
      array = full_file_list.select { |item| item.include?(type.to_s) }
      t.libs << 'test'
      t.test_files = array
    end
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
  desc 'Download OpenStudio_Standards from Google & export JSONs'
  task 'update' do
    download_google_spreadsheet
    export_spreadsheet_to_json
  end

  desc 'Export JSONs from OpenStudio_Standards'
  task 'update:manual' do
    export_spreadsheet_to_json
  end

=begin
  desc 'Update RS-Means Database'
  task 'update:costing' do
    $LOAD_PATH.unshift File.expand_path('lib', __FILE__)
    require 'openstudio'
    require 'openstudio/ruleset/ShowRunnerOutput'
    # Require local version instead of installed version for developers
    begin
      require_relative 'lib/openstudio-standards.rb'
      puts 'DEVELOPERS OF OPENSTUDIO-STANDARDS: Requiring code directly instead of using installed gem.  This avoids having to run rake install every time you make a change.'
    rescue LoadError
      require 'openstudio-standards'
      puts 'Using installed openstudio-standards gem.'
    end
    BTAPCosting.instance
  end
=end
end

# Tasks to export libraries packaged with
# the OpenStudio installer
namespace :library do
  require "#{File.dirname(__FILE__)}/data/standards/export_OpenStudio_libraries.rb"
  desc 'Export libraries for OpenStudio installer'
  task 'export' do
    export_openstudio_libraries
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
