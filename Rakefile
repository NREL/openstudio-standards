require 'bundler'
Bundler.setup

require 'rake'

namespace :build do

  desc 'Create Standards JSON'
  task :standards do

    require_relative 'openstudio_standards_json'

    a = OpenStudio::StandardsJson.create
  end
end

require 'rubocop/rake_task'
desc 'Run RuboCop for Static Code Analysis'
RuboCop::RakeTask.new(:rubocop) do |task|
  task.options = ['--no-color', '--out=rubocop-results.xml']
  task.formatters = ['RuboCop::Formatter::CheckstyleFormatter']
  task.requires = ['rubocop/formatter/checkstyle_formatter']
  # don't abort rake on failure
  task.fail_on_error = false
end
