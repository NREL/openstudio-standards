require_relative '../../../helpers/minitest_helper'
require_relative '../../../helpers/necb_helper'
include(NecbHelper)

class NECB_ECM_Envelope < Minitest::Test


  def setup()
    define_folders(__dir__)
    define_std_ranges
  end

  # Test to validate hot water loop rules
  def test_ecm_envelope

    # Set up remaining parameters for test.
    output_folder = method_output_folder(__method__)
    templates = [
      'BTAPPRE1980',
      'NECB2020'
    ]
    building_type = 'FullServiceRestaurant'
    primary_heating_fuel = 'NaturalGas'
    epw_file = 'CAN_BC_Vancouver.Intl.AP.718920_CWEC2020.epw'
    wall_conds = [
      '0.278',
      '0.183'
    ]

    roof_conds = [
      '0.162',
      '0.121'
    ]

    ground_floor_conds = [
      '0.758',
      '0.379'
    ]

    envelope_output = []

    # Generate the osm files for all relevant cases to generate the envelope test data
    templates.sort.each do |template|
      standard = get_standard(template)
      wall_conds.sort.each do |wall_cond|
        roof_conds.sort.each do |roof_cond|
          ground_floor_conds.sort.each do |ground_floor_cond|
            output_info = {
              standard: template,
              wall_cond: wall_cond,
              roof_cond: roof_cond,
              ground_floor_cond: ground_floor_cond,
              surfaces: []
            }
            model = standard.model_create_prototype_model(building_type: building_type,
                                                          epw_file: epw_file,
                                                          template: template,
                                                          primary_heating_fuel: primary_heating_fuel,
                                                          sizing_run_dir: output_folder,
                                                          ext_wall_cond: wall_cond,
                                                          ext_roof_cond: roof_cond,
                                                          ground_floor_cond: ground_floor_cond)
            surfs = model.getSurfaces
            env_surfaces = surfs.select{ |surf| surf.outsideBoundaryCondition == 'Outdoors' || surf.outsideBoundaryCondition == 'Foundation' || surf.outsideBoundaryCondition == 'Ground' }
            env_surfaces.sort.each do |env_surface|
              therm_cond = env_surface.thermalConductance
              output_info[:surfaces] << {
                space: env_surface.space.get.name.to_s,
                surface_name: env_surface.name.get.to_s,
                outside_boundary_condition: env_surface.outsideBoundaryCondition,
                thermal_conductance: therm_cond.get.to_f.round(4)
              }
            end
            envelope_output << output_info
          end
        end
      end
    end
    # Create the test file.  If no expected results file exists create the expected results file from the test results.
    envelope_expected_results = File.join(@expected_results_folder, 'ecm_envelope_expected_result.json')
    envelope_test_results = File.join(@test_results_folder, 'ecm_envelope_test_result.json')
    unless File.exist?(envelope_expected_results)
      puts("No expected results file, creating one based on test results")
      File.write(envelope_expected_results, JSON.pretty_generate(envelope_output))
    end
    File.write(envelope_test_results, JSON.pretty_generate(envelope_output))
    msg = "The ecm_envelope_test_result.json differs from the ecm_envelope_expected_results.json.  Please review the results."
    file_compare(expected_results_file: envelope_expected_results, test_results_file: envelope_test_results, msg: msg)
  end
end
