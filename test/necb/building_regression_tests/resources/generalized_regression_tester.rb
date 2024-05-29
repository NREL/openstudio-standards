require 'json'
require_relative 'regression_helper'

class GeneralizedRegressionHelper < NECBRegressionHelper

  def setup()
    # *** Setup variables are inherited from regression_helper.rb ***
    super

    # These are the default parameters which will be passed to Standards
    # Additional parameters specified will be appended to this hash
    #
    # These four parameters are currently necessary for template creation:
    #   building type
    #   epw_file
    #   template
    #   primary_heating_fuel
    #
    # Stored in singleton lists--this is for the combinations
    @params =
    {
      building_type:               [@building_type],
      epw_file:                    [@epw_file],
      template:                    [@template],
      primary_heating_fuel:        [@primary_heating_fuel],
      # This parameter breaks it for some reason,
      # but it's not used anywhere in regression_helper.rb anyways
      # necb_reference_hp:           [@reference_hp]
    }

    # These are the variable parameters
    # The keys should match the parameter names respective to the correct template file
    # These will take precedence over the previously defined parameters if there are any
    @param_groups =
    {
      # TODO These should be taken from a test class
      template:
        [
          "NECB2011",
          "NECB2015",
          "NECB2017",
          "NECB2020"
        ],
      primary_heating_fuel:
        [
          "Electricity",
          "NaturalGas",
        ],
      ecm_system_name:
        [
          "HS11_ASHP_PTHP" # This will run but spews a ton of fan and coil-related errors
        ]
    }
  end

  # TODO These should be taken from a test class

  # TODO Each combination should be its own test

  def create_model_and_regression_tests(params: @params)

    # Create all the combinations for each vintage
    # Merge the default parameters with the param_groups
    self.create_test_vintages(@params.merge(@param_groups), @expected_results_folder)

    result, diff = self.osm_regression(expected_results_folder: @expected_results_folder)
    if run_simulation
      self.run_simulation()
      #self.qaqc_regression()
      end
    return result, diff
  end


  def create_test_vintages(params, err_folder)
    # This is the function that creates each combination of model according to
    # the params function argument

    # The params argument contains the parameters which remain static for each
    # combination

    # Variable-nested for-loop to create and test each combination of models
    # From https://stackoverflow.com/a/20577981

    pos             = 0                      # Position of the current index
    num_params      = params.length          # Number of attributes
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

      # Handle models that couldn't be created and output the errors
      begin
        create_model_from_hash(model_params)
      rescue => exception
        err_file = "#{err_folder}#{@model_name}_diffs.json"
        error = "#{exception.backtrace.first}: #{exception.message} (#{exception.class})"
        exception.backtrace.drop(1).map {|s| "\n#{s}"}.each {|bt| error << bt.to_s}
        File.write(err_file, JSON.pretty_generate(error))
      end

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
  def create_model_from_hash(model_params)

    building_type        = model_params[:building_type]
    epw_file             = model_params[:epw_file]
    template             = model_params[:template]
    primary_heating_fuel = model_params[:primary_heating_fuel]

    # Generate the name for the model
    # TODO how should the name look like?
    # @model_name = ""
    #
    # model_params.values do |value|
    #   @model_name += value + "--"
    # end
    #
    # @model_name += File.basename(epw_file, '.epw')

    @model_name = "#{building_type}-#{template}-#{primary_heating_fuel}-#{File.basename(epw_file, '.epw')}"


    @run_dir = "#{@test_dir}/#{@model_name}"

    # Create a key/value pair for the run directory to include it as an argument
    model_params[:sizing_run_dir] = @run_dir

    #create folders
    if !Dir.exists?(@test_dir)
      Dir.mkdir(@test_dir)
    end
    if !Dir.exists?(@run_dir)
      Dir.mkdir(@run_dir)
    end

    puts "========================model_name =================== #{@model_name}"
    puts("Parameters for the current model:")
    puts
    model_params.each do |key, value|
      puts("#{key.to_s.ljust(30)}: #{value}")
    end
    puts
    @model = Standard.build("#{template}").model_create_prototype_model(**model_params)
    unless @model.instance_of?(OpenStudio::Model::Model)
      puts "Creation of Model for #{@model_name} failed. Please check output for errors."
    end
    return self
  end
end

