require_relative '../libs.rb'
class BTAP_CLI_Test < Minitest::Test
  def test_cli
    input_folder = File.join(__dir__, '..', 'input')
    input_folder_cache = File.join(__dir__, '..', 'input_cache')
    output_folder = File.join(__dir__, '..', 'output')
    # Make sure temp folder is always clean.
    FileUtils.rm_rf(input_folder) if Dir.exist?(input_folder)
    FileUtils.rm_rf(input_folder_cache) if Dir.exist?(input_folder_cache)
    FileUtils.rm_rf(output_folder) if Dir.exist?(output_folder)
    FileUtils.mkdir_p(input_folder)
    FileUtils.cp(File.join(__dir__, 'run_options.yml'), input_folder)
    BTAPDatapoint.new(input_folder: input_folder, output_folder: output_folder, input_folder_cache: File.join(__dir__, 'input_cache'))
  end
end
