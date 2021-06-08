require 'minitest/autorun'
require 'openstudio'

#if running from openstudio-standards.. load local standards
os_standards_local_lib_path = '../../../lib/openstudio-standards.rb'
if Dir.exist?(os_standards_local_lib_path )
  require_relative os_standards_local_lib_path
else
  require 'openstudio-standards'
end

#load costing files if we are in btap_costing repository
resource_folder = File.join(__dir__, '..','..', '..', 'measures/btap_results/resources')

if Dir.exist?(resource_folder)
  puts('Loading Costing libs')
  require_relative File.join(resource_folder, 'os_lib_reporting')
  require_relative File.join(resource_folder, 'os_lib_schedules')
  require_relative File.join(resource_folder, 'os_lib_helper_methods')
  require_relative File.join(resource_folder, 'btap_measure_helper')
  require_relative File.join(resource_folder, 'btap_costing.rb')
  require_relative File.join(resource_folder, 'ventilation_costing.rb')
  require_relative File.join(resource_folder, 'envelope_costing.rb')
  require_relative File.join(resource_folder, 'lighting_costing.rb')
  require_relative File.join(resource_folder, 'heating_cooling_costing.rb')
  require_relative File.join(resource_folder, 'shw_costing.rb')
  require_relative File.join(resource_folder, 'btap_data.rb')
  require_relative File.join(resource_folder, 'dcv_costing.rb')
  require_relative File.join(resource_folder, 'daylighting_sensor_control_costing.rb')
  require_relative File.join(resource_folder, 'led_lighting_costing.rb')
  require_relative File.join(resource_folder, 'pv_ground_costing.rb')
  require_relative File.join(resource_folder, 'nv_costing.rb')
end
class BTAP_CLI_Test < Minitest::Test

  def test_cli_local_osm()
    input_folder = File.join(__dir__,'..','input')
    input_folder_cache = File.join(__dir__,'..','input_cache')
    output_folder = File.join(__dir__,'..','output')
    # Make sure temp folder is always clean.
    FileUtils.rm_rf(input_folder) if Dir.exist?(input_folder)
    FileUtils.rm_rf(input_folder_cache) if Dir.exist?(input_folder_cache)
    FileUtils.rm_rf(output_folder) if Dir.exist?(output_folder)
    FileUtils.mkdir_p(input_folder)
    FileUtils.cp(File.join(__dir__, 'run_options_local_osm.yml'), File.join(input_folder,'run_options.yml'))
    FileUtils.cp(File.join(__dir__, 'LocalFullServiceRestaurant.osm'), File.join(input_folder,'LocalFullServiceRestaurant.osm'))
    BTAPDatapoint.new(input_folder: input_folder, output_folder: output_folder, input_folder_cache: File.join(__dir__, 'input_cache'))
  end
end

