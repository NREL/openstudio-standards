require_relative '../libs'
class BTAPCLITest < Minitest::Test
  def test_cli
    input_folder = File.join(__dir__, '..', 'input')
    input_folder_cache = File.join(__dir__, '..', 'input_cache')
    output_folder = File.join(__dir__, '..', 'output')
    weather_folder = File.join(__dir__, ['..', 'weather'])
    # Make sure temp folder is always clean.
    FileUtils.rm_rf(input_folder)
    FileUtils.rm_rf(input_folder_cache)
    FileUtils.rm_rf(output_folder)
    FileUtils.mkdir_p(input_folder)
    FileUtils.cp(File.join(__dir__, 'run_options.yml'), input_folder)
    FileUtils.cp(File.join(__dir__, 'costs.csv'), input_folder)
    FileUtils.cp(File.join(__dir__, 'local_cost_factors.csv'), input_folder)
    BTAPDatapoint.new(input_folder: input_folder, output_folder: output_folder, weather_folder: weather_folder, input_folder_cache: File.join(__dir__, 'input_cache'))
  end
end
