require_relative '../../../helpers/minitest_helper'
require_relative '../../../helpers/necb_helper'
include(NecbHelper)


class NECB_HVAC_Template < Minitest::Test

  # Set to true to run the standards in the test.
  PERFORM_STANDARDS = true

  def setup()
    define_folders(__dir__)
    define_std_ranges
  end


  # Test to validate the boiler thermal efficiency generated against expected values.
  def test_template

    # Set up remaining boilerplate parameters for test.
    output_folder = method_output_folder(__method__)
    save_intermediate_models = false

    # Define test specific parameters.
    fueltypes = ['Electricity','NaturalGas','FuelOilNo2']

    # Read expected results. This is used to set the tested cases as the parameters change depending on the
    # fuel type and boiler size.
    file_root = "#{self.class.name}-#{__method__}".downcase
    file_name = File.join(@expected_results_folder, "#{file_root}-expected_results.json")
    expected_results = JSON.parse(File.read(file_name), {symbolize_names: true})

    # Initialize test results hash.
    test_results = {}

    # Loop through the templates rather than using those defined in the file (this way we identify if any are missing).
    @AllTemplates.each do |template|

      # Create empty entry for the test cases results and copy over the reference.
      # If reference missing add a placeholder.
      template_cases_results = {}
      begin
        template_cases_results[:reference] = expected_results[template.to_sym][:reference]
      rescue NoMethodError => error
        template_cases_results[:reference] = "Reference required"
        test_results[template.to_sym] = template_cases_results
        puts "ERROR: #{error.message}\n This was probably triggered by the template not existing in the expected results set. Continue and report at end.ERROR: #{error.message}"
        next
      end

      # Load template/standard.
      standard = get_standard(template)

      # Loop through the fuels rather than using those defined in the file (this way we identify if any are missing).
      fueltypes.each do |fueltype|

        # Create empty entry this test case results.
        individual_case_results = {}

        # Loop through the individual test cases.
        test_cases = expected_results[template.to_sym][fueltype.to_sym]
        next if test_cases.nil?
        test_cases.each do |key, test_case|

          # Define local variables.
          case_name = key.to_s
          fueltype = fueltype.to_s
          boiler_cap = test_case[:tested_capacity_kW]
          efficiency_metric = test_case[:efficiency_metric]

          # Define the test name. 
          name = "#{template}_sys1_Boiler-#{fueltype}_cap-#{boiler_cap.to_int}kW"
          name.gsub!(/\s+/, "-")
          puts "***************#{name}***************\n"

          # Wrap test in begin/rescue/ensure.
          begin

            # Load model and set climate file.
            model = BTAP::FileIO.load_osm(File.join(@resources_folder,"5ZoneNoHVAC.osm"))
            BTAP::Environment::WeatherFile.new('CAN_ON_Toronto.Pearson.Intl.AP.716240_CWEC2016.epw').set_weather_file(model)
            BTAP::FileIO.save_osm(model, "#{output_folder}/#{name}-baseline.osm") if save_intermediate_models

            # Guts of test go here.

            # Run sizing.
            run_sizing(model: model, template: template, test_name: name, save_model_versions: save_intermediate_models) if PERFORM_STANDARDS
          rescue => error
            puts "Something went wrong! #{error.message}"
          end

          # Recover the thermal efficiency set in the measure for checking below.
          test_efficiency_value = 0
          model.getBoilerHotWaters.each do |iboiler|
            if iboiler.nominalCapacity.to_f > 1
              test_efficiency_value = iboiler.nominalThermalEfficiency
              break
            end
          end

          # Convert efficiency depending on the metric being used.
          if efficiency_metric == 'annual fuel utilization efficiency'
            test_efficiency_value = standard.thermal_eff_to_afue(test_efficiency_value)
          elsif efficiency_metric == 'combustion efficiency'
            test_efficiency_value = standard.thermal_eff_to_comb_eff(test_efficiency_value)
          elsif efficiency_metric == 'thermal efficiency'
            test_efficiency_value = test_efficiency_value
          end

          # Add this test case to results.
          individual_case_results[case_name.to_sym] = {
            name: name,
            tested_capacity_kW: boiler_cap.signif,
            efficiency_metric: efficiency_metric,
            efficiency_value: test_efficiency_value.signif(3)
          }
        rescue NoMethodError => error
          test_results[template.to_sym][fueltype.to_sym] = {}
          puts "Probably triggered by the template not existing in the expected results set. Continue and report at end.\n#{error.message}"
        end

        # Add this fueltype test case to results hash.
        template_cases_results[fueltype.to_sym] = individual_case_results
      end

      # Add results for this template to the results hash.
      test_results[template.to_sym] = template_cases_results
    end

    # Write test results.
    test_result_file = File.join(@test_results_folder, "#{file_root}-test_results.json")
    File.write(test_result_file, JSON.pretty_generate(test_results))

    # Check if test results match expected.
    msg = "Boiler efficiencies test results do not match what is expected in test"
    file_compare(expected_results_file: expected_results, test_results_file: test_results, msg: msg, type: 'json_data')
  end
