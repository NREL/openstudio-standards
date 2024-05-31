require_relative '../../../helpers/minitest_helper'
require_relative '../../../helpers/create_doe_prototype_helper'
require_relative '../../../helpers/necb_helper'
include(NecbHelper)

class NECB_BTAP_Data_Reporting < Minitest::Test


  def setup()
    define_folders(__dir__)
    define_std_ranges
  end

  # Test to validate btap_data.json generation
  def test_btap_data_reporting

    # Set up remaining parameters for test.
    output_folder = method_output_folder(__method__)
    template = 'NECB2011'
    standard = get_standard(template)
    save_intermediate_models = true

    # Generate the osm files for all relevant cases to generate the test data for system 6
    building_type = 'FullServiceRestaurant'
    primary_heating_fuel = 'NaturalGas'
    epw_file = 'CAN_QC_Montreal.Intl.AP.716270_CWEC2020.epw'
    #epw_file = 'CAN_ON_Toronto.Intl.AP.716240_CWEC2020.epw'
    # Generate osm file.
    model = standard.model_create_prototype_model(building_type: building_type,
                                                  epw_file: epw_file,
                                                  template: template,
                                                  primary_heating_fuel: primary_heating_fuel,
                                                  sizing_run_dir: output_folder)

    standard.model_run_simulation_and_log_errors(model, output_folder)
    # Create the results file
    qaqc = standard.init_qaqc(model)
    # Replace the openstudio-standards version with test to avoid the test failing with every commit to a branch.
    qaqc[:os_standards_revision] = "test"
    qaqc[:os_standards_version] = "test"
    qaqc[:openstudio_version] = "test"
    qaqc[:energyplus_version] = "test"
    btap_data_out = BTAPData.new(model: model,
                              runner: nil,
                              cost_result: nil,
                              qaqc: qaqc,
                              npv_start_year: 2010,
                              npv_end_year: 2030,
                              npv_discount_rate: @npv_discount_rate).btap_data
    #btap_data_out.select.first
    btap_data_out["simulation_btap_data_version"] = "test"
    btap_data_out["simulation_os_standards_revision"] = "test"
    btap_data_out["simulation_os_standards_version"] = "test"
    btap_data_out["simulation_date"] = "test"
    btap_data_expected_results = File.join(@expected_results_folder, 'btap_data_report_expected_result.json')
    btap_data_test_results = File.join(@test_results_folder, 'btap_data_report_test_result.json')
    unless File.exist?(btap_data_expected_results)
      puts("No expected results file, creating one based on test results")
      File.write(btap_data_expected_results, JSON.pretty_generate(btap_data_out))
    end
    File.write(btap_data_test_results, JSON.pretty_generate(btap_data_out))
    msg = "The btap_data_report_test_results.json differs from the btap_data_report_expected_results.json.  Please review the results."
    file_compare(expected_results_file: btap_data_expected_results, test_results_file: btap_data_test_results, msg: msg)
  end
end
