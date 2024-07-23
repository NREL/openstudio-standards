require 'minitest/autorun'
require 'json'
require 'fileutils'
require_relative '../../../helpers/minitest_helper'
require_relative '../../../helpers/necb_helper'
include NecbHelper

class NECB_SHW_Fuel < Minitest::Test

  def setup
    define_folders(__dir__)
    define_std_ranges
  end

  def test_btap_shw_fuel
    output_folder = method_output_folder(__method__)
    templates = ['BTAP1980TO2010', 'NECB2020']

    
    building_type = 'FullServiceRestaurant'
    primary_heating_fuel = 'NaturalGas'
    shw_fuels = ['NECB_Default', 'Electricity', 'NaturalGas', 'FuelOilNo2']
    epw_file = 'CAN_ON_Toronto.Intl.AP.716240_CWEC2020.epw'

    shw_out_data = []
    templates.sort.each do |template|
      standard = get_standard(template)
      shw_fuels.sort.each do |shw_fuel|
        puts ''
        puts '##################################'
        puts template
        puts shw_fuel
        puts '##################################'
        puts ''
        model = standard.model_create_prototype_model(building_type: building_type,
                                                      epw_file: epw_file,
                                                      template: template,
                                                      primary_heating_fuel: primary_heating_fuel,
                                                      shw_fuel: shw_fuel,
                                                      sizing_run_dir: output_folder)
        shw_out = {
          template: template,
          test_fuel: shw_fuel,
          shw_tanks: []
        }
        water_heaters = model.getWaterHeaterMixeds
        water_heaters.each do |wh|
          shw_out[:shw_tanks] << {
            name: wh.name.get.to_s,
            tankVolume: wh.tankVolume.get.to_f,
            heaterFuelType: wh.heaterFuelType,
            Efficiency: wh.heaterThermalEfficiency.get.to_f
          }
        end
        shw_out_data << shw_out
      end
    end

    shw_expected_results = File.join(@expected_results_folder, 'shw_fuel_expected_result.json')
    shw_test_results = File.join(@test_results_folder, 'shw_fuel_test_result.json')
    unless File.exist?(shw_expected_results)
      puts("No expected results file, creating one based on test results")
      File.write(shw_expected_results, JSON.pretty_generate(shw_out_data))
    end
    File.write(shw_test_results, JSON.pretty_generate(shw_out_data))
    msg = "The shw_fuel_test_result.json differs from the shw_fuel_expected_result.json. Please review the results."
    file_compare(expected_results_file: shw_expected_results, test_results_file: shw_test_results, msg: msg)
  end
end
