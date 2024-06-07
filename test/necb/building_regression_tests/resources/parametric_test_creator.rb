require_relative '../../../helpers/minitest_helper'
require_relative '../../../helpers/compare_models_helper'
require_relative '../resources/parametric_regression_helper'

=begin

Parametric Regression Test Creator

This class is made to support the testing of models with a pre-defined set of variable parameters to make combinations
out of.

Currently, it supports the creation of models with these parameters:
  *building type
  *epw_file
  *template
  *primary_heating_fuel
  ecm_system_name

The parameters marked with * are necessary and are inherited from regression_helper.rb. These will be defaulted if none
are specified.

The remaining ones are optional and are defaulted as specified by the class corresponding to the chosen template.

Although this should support each parameter outlined in the template files, this restriction is due to how the naming
conventions are currently handled.

=end

class ParametricTestCreator < ParametricRegressionHelper
  # The generation of methods has to be at the class level so Minitest doesn't skip them before they initialize
  class << self
    def generate_tests(params)
      # These are the default parameters which will be passed to Standards
      # Additional parameters specified will be merged into this hash

      # Stored in singleton lists--this is for the combinations
      @params_default =
        {
          building_type:        ['FullServiceRestaurant'],
          epw_file:             ['CAN_AB_Calgary.Intl.AP.718770_CWEC2020.epw'],
          template:             ['NECB2011'],
          primary_heating_fuel: ['Electricity']
        }

      params = @params_default.merge(params)

      # This is the function that creates each combination of model according to
      # the params function argument

      # The params argument contains the parameters which remain static for each
      # combination

      # Variable-nested for-loop to create and test each combination of models
      # From https://stackoverflow.com/a/20577981

      pos             = 0                      # Position of the current index
      num_params      = params.length         # Number of attributes
      curr_indicies   = [0] * (num_params + 1) # Current index of each list
      max_indicies    = [0] * (num_params + 1) # Max length of each list

      # Set each max index to the correct length
      0.upto num_params - 1 do |i|
        max_indicies[i] = params.values[i].length
      end

      while curr_indicies[num_params] == 0

        # Main control flow
        # This is where the models are created

        model_params = {} # Combination of parameters unique to this iteration

        0.upto num_params - 1 do |i|
          model_params[params.keys[i]] = params.values[i][curr_indicies[i]]
        end

        model_name = generate_model_name(model_params)
        
        # Method creation wrapped in a lambda to preserve the context of the variables during method creation
        create_test_method = Proc.new do |curr_model_name, curr_model_params|
          
          # Metaprogramming to generate test methods for each combination of parameters
          # Minitest requires each test to be a method starting with "test_"
          define_method("test_#{curr_model_name}") do

            result, diff = create_model_and_regression_test(curr_model_name, curr_model_params)
            if result == false
              puts "JSON terse listing of diff-errors."
              puts diff
              puts "Pretty listing of diff-errors for readability."
              puts JSON.pretty_generate( diff )
              puts "You can find the saved json diff file here: #{curr_model_name}_diffs.json"
              puts "outputting errors here. "
              puts diff["diffs-errors"] if result == false
            end
            assert(result, diff)
          end  
        end

        create_test_method.call(model_name, model_params)

        # Iteration logic
        curr_indicies[0] += 1
        while curr_indicies[pos] == max_indicies[pos]
          curr_indicies[pos] = 0
          pos += 1
          curr_indicies[pos] += 1

          if curr_indicies[pos] != max_indicies[pos]
            pos = 0
          end
        end
      end
    end
    
    # Generates the name of the model from the set of parameters provided
    def generate_model_name(params)
      # TODO Currently, this function only supports these 5 parameters until a different naming convention is proposed.

      building_type        = params[:building_type]
      epw_file             = params[:epw_file]
      template             = params[:template]
      primary_heating_fuel = params[:primary_heating_fuel]
      ecm_system_name      = params[:ecm_system_name]

      if !(params.key?(:ecm_system_name))
        return "#{building_type}-#{template}-#{primary_heating_fuel}-#{File.basename(epw_file, '.epw')}"
      else
        return "#{building_type}-#{template}-#{primary_heating_fuel}-#{ecm_system_name}#{File.basename(epw_file, '.epw')}"
      end
    end
  end
end

