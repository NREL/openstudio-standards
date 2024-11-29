require_relative '../../../helpers/minitest_helper'
require_relative '../../../helpers/necb_helper'
include(NecbHelper)

class NECB_QAQC_Reporting < Minitest::Test


  def setup()
    define_folders(__dir__)
    define_std_ranges
  end

  # Test to validate hot water loop rules
  def test_qaqc_reporting

    # Set up remaining parameters for test.
    output_folder = method_output_folder(__method__)
    template = 'NECB2011'
    standard = get_standard(template)
    save_intermediate_models = true

    # Generate the osm files for all relevant cases to generate the test data for system 6
    building_type = 'FullServiceRestaurant'
    primary_heating_fuel = 'NaturalGas'
    epw_file = 'CAN_QC_Montreal.Intl.AP.716270_CWEC2020.epw'
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
    # Create the test file.  If no expected results file exists create the expected results file from the test results.
    qaqc_expected_results = File.join(@expected_results_folder, 'qaqc_report_expected_result.json')
    qaqc_test_results = File.join(@test_results_folder, 'qaqc_report_test_result.json')
    unless File.exist?(qaqc_expected_results)
      puts("No expected results file, creating one based on test results")
      File.write(qaqc_expected_results, JSON.pretty_generate(qaqc))
    end
    File.write(qaqc_test_results, JSON.pretty_generate(qaqc))
    msg = "The qaqc_report_test_results.json differs from the qaqc_report_expected_results.json.  Please review the results."
    file_compare(expected_results_file: qaqc_expected_results, test_results_file: qaqc_test_results, msg: msg)
  end
end
