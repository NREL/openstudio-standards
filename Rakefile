require 'bundler'
Bundler.setup

require 'rake'

namespace :build do
  desc 'Export OpenStudio_Standards.json from Excel'
  task :standards do
    require_relative 'lib/openstudio_standards_json'

    OpenStudio::StandardsJson.export_json
  end

  desc 'Create OpenStudio Template Models'
  task :template_models do
    require_relative 'lib/create_template_models'

    create_template_models
  end

  desc 'Create osm with T24/CEC Constructions/Materials'
  task :cec_template do
    require_relative 'lib/create_template_models'

    generate_cec_template
  end
end

namespace :test do
  desc 'Test validity and uniqueness of OpenStudio_Standards.json export'
  task :check_validity do
    require_relative 'test/test_validity_of_openstudio_standards_json'

    check_validity
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
