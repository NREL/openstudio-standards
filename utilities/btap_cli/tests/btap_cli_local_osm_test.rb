require_relative '../libs'
class BTAP_CLI_Test < Minitest::Test
  def test_cli_local_osm
    input_folder = File.join(__dir__, '..', 'input')
    input_folder_cache = File.join(__dir__, '..', 'input_cache')
    output_folder = File.join(__dir__, '..', 'output')
    weather_folder = File.join(__dir__, ['..', 'weather'])
    # Make sure temp folder is always clean.
    FileUtils.rm_rf(input_folder)
    FileUtils.rm_rf(input_folder_cache)
    FileUtils.rm_rf(output_folder)
    FileUtils.mkdir_p(input_folder)
    # Run options and local osm file locations
    FileUtils.cp(File.join(__dir__, 'run_options_local_osm.yml'), File.join(input_folder, 'run_options.yml'))
    FileUtils.cp(File.join(__dir__, 'LocalCompleteModel.osm'), File.join(input_folder, 'LocalCompleteModel.osm'))
    BTAPDatapoint.new(input_folder: input_folder, output_folder: output_folder, weather_folder: weather_folder, input_folder_cache: File.join(__dir__, 'input_cache'))
  end
end
