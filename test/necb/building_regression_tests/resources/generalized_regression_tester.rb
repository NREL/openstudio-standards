require_relative '../../../helpers/minitest_helper'
require_relative '../../../helpers/compare_models_helper'
require_relative '../resources/regression_helper'

class Standards_Generalzied_Tester < Minitest::Test

  def setup()
    @building_type              = 'FullServiceRestaurant'
    @epw_file                   = 'CAN_AB_Calgary.Intl.AP.718770_CWEC2020.epw'
    @template                   = 'NECB2011'
    @primary_heating_fuel       = "Electricity"
    @ecm_system_type            = 'HS11_ASHP_PTHP'
    @test_dir                   = "#{File.dirname(__FILE__)}/output"
    @expected_results_folder    = "#{File.dirname(__FILE__)}/../expected_results/"
    @model                      = nil
    @model_name                 = nil
    @run_simulation             = false
    @reference_hp               = false
  end

  def create_and_run_model_tests(
    building_type: @building_type,
    epw_file: @epw_file,
    template: @template,
    primary_heating_fuel: @primary_heating_fuel,
    ecm_system_type: @ecm_system_type,
    test_dir: @test_dir,
    expected_results_folder: @expected_results_folder,
    run_simulation: @run_simulation,
    reference_hp: @reference_hp
  )

    @epw_file                   = epw_file
    @template                   = template
    @building_type              = building_type
    @test_dir                   = test_dir
    @expected_results_folder    = expected_results_folder
    @primary_heating_fuel       = primary_heating_fuel
    @reference_hp               = reference_hp

    self.create_model(
      building_type: @building_type,
      epw_file: @epw_file,
      template: @template,
      primary_heating_fuel: @primary_heating_fuel
    ecm_system_type: @ecm_system_type,
      test_dir: @test_dir,
    )

    result, diff = self.osm_regression(expected_results_folder: @expected_results_folder)
    if run_simulation
      self.run_simulation()
      #self.qaqc_regression()
    end
    return result, diff
  end

  # Variable-nested for-loop to create and test each combination of models
  # From https://stackoverflow.com/a/20577981

  pos           = 0                        # Position of the current index
  num_elements  = elements.length          # Number of attributes
  curr_indicies = [0] * (num_elements + 1) # Current index of each list
  max_indicies  = [0] * (num_elements + 1) # Max length of each list

  0.upto num_elements - 1 do |i|
    max_indicies[i] = elements[i].length # Set each max index to the correct length
  end

  while (curr_indicies[num_elements] == 0)

    0.upto num_elements - 1 do |i|
      model_args = []
      model_args.append(elements[i][curr_indicies[i]])
      create_model(*model_args)
    end

    curr_indicies[0] += 1
    while (curr_indicies[pos] == max_indicies[pos])
      curr_indicies[pos] = 0
      pos += 1
      curr_indicies[pos] += 1

      if (curr_indicies[pos] != max_indicies[pos])
        pos = 0
      end
    end
  end
end

def create_model(
  building_type,
  template,
  climate_zone,
  epw_file,
  create_models = true,
  run_models = false,
  compare_results = false,
  debug = false,
  run_type = 'annual',
  compare_results_object_by_object = false,
  test_name_prefix = ''
)


