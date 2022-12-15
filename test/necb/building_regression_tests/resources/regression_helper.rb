require 'minitest/unit'
require 'json'


class NECBRegressionHelper < Minitest::Test

  def setup()
    @building_type = 'FullServiceRestaurant'
    @epw_file = 'CAN_AB_Calgary.Intl.AP.718770_CWEC2016.epw'
    @template = 'NECB2011'
    @test_dir = "#{File.dirname(__FILE__)}/output"
    @expected_results_folder = "#{File.dirname(__FILE__)}/../expected_results/"
    @model = nil
    @model_name = nil
    @run_simulation = false
    @primary_heating_fuel = "Electricity"
    @reference_hp = false
  end


  def create_model_and_regression_test(building_type: @building_type,
                                       epw_file: @epw_file,
                                       template: @template,
                                       test_dir: @test_dir,
                                       expected_results_folder: @expected_results_folder,
                                       run_simulation: @run_simulation,
                                       primary_heating_fuel: @primary_heating_fuel,
                                       reference_hp: @reference_hp
  )
    @epw_file = epw_file
    @template = template
    @building_type = building_type
    @test_dir = test_dir
    @expected_results_folder = expected_results_folder
    @primary_heating_fuel = primary_heating_fuel
    @reference_hp = reference_hp
    self.create_model(building_type: @building_type,
                      epw_file: @epw_file,
                      template: @template,
                      test_dir: @test_dir,
                      primary_heating_fuel: @primary_heating_fuel,
                      reference_hp: @reference_hp)

    result, diff = self.osm_regression(expected_results_folder: @expected_results_folder)
    if run_simulation
      self.run_simulation()
      #self.qaqc_regression()
    end
    return result, diff
  end


  def create_model(epw_file: @epw_file,
                   template: @template,
                   building_type: @building_type,
                   test_dir: @test_dir,
                   primary_heating_fuel: @primary_heating_fuel,
                   reference_hp: @reference_hp)
    #set paths
    unless reference_hp
      @model_name = "#{building_type}-#{template}-#{primary_heating_fuel}-#{File.basename(epw_file, '.epw')}"
    else
      @model_name = "#{building_type}-#{template}-RefHP-#{primary_heating_fuel}-#{File.basename(epw_file, '.epw')}"
    end
    @run_dir = "#{test_dir}/#{@model_name}"
    #create folders
    if !Dir.exists?(test_dir)
      Dir.mkdir(test_dir)
    end
    if !Dir.exists?(@run_dir)
      Dir.mkdir(@run_dir)
    end
    puts "========================model_name =================== #{@model_name}"
    puts "reference_hp #{reference_hp}"
    @model = Standard.build("#{template}").model_create_prototype_model(epw_file: epw_file,
                                                                        sizing_run_dir: @run_dir,
                                                                        template: template,
                                                                        building_type: building_type,
                                                                        primary_heating_fuel: primary_heating_fuel,
                                                                        necb_reference_hp: reference_hp)
    unless @model.instance_of?(OpenStudio::Model::Model)
      puts "Creation of Model for #{@model_name} failed. Please check output for errors."
    end
    return self
  end

  def create_iterative_model_and_regression_test(building_type: @building_type,
                                                epw_file: @epw_file,
                                                template: @template,
                                                test_dir: @test_dir,
                                                expected_results_folder: @expected_results_folder,
                                                run_simulation: @run_simulation,
                                                primary_heating_fuel: @primary_heating_fuel,
                                                reference_hp: @reference_hp,
                                                iteration: int)
    # Update global variables ()
    @epw_file = epw_file
    @template = template
    @building_type = building_type
    @test_dir = test_dir
    @expected_results_folder = expected_results_folder
    @primary_heating_fuel = primary_heating_fuel
    @reference_hp = reference_hp

    #set paths
    unless reference_hp
      @model_name = "#{building_type}-#{template}-#{primary_heating_fuel}-#{File.basename(epw_file, '.epw')}-iteration#{iteration}"
    else
      @model_name = "#{building_type}-#{template}-RefHP-#{primary_heating_fuel}-#{File.basename(epw_file, '.epw')}-iteration#{iteration}"
    end
    @run_dir = "#{test_dir}/#{@model_name}"
    #create folders
    if !Dir.exists?(test_dir)
      Dir.mkdir(test_dir)
    end
    if !Dir.exists?(@run_dir)
      Dir.mkdir(@run_dir)
    end
    puts "========================model_name =================== #{@model_name}"
    puts "reference_hp #{reference_hp}"
    # Load model from library, instead of prototype
    @model = Standard.build("#{template}").load_building_type_from_library(building_type: building_type)

    # Apply spacetype measure, based on iteration argument
    apply_spacetype_iteration_to_model(model: @model, iteration: iteration)
    # Apply necb standard
    @model = Standard.build("#{template}").model_apply_standard(model: @model,
                        epw_file: epw_file,
                        sizing_run_dir: @run_dir,
                        primary_heating_fuel: primary_heating_fuel,
                        necb_reference_hp: reference_hp)

    unless @model.instance_of?(OpenStudio::Model::Model)
      puts "Creation of Model for #{@model_name} failed. Please check output for errors."
    end

    result, diff = self.osm_regression(expected_results_folder: @expected_results_folder)
    if run_simulation
      self.run_simulation()
      #self.qaqc_regression()
    end
    return result, diff

  end

  def osm_regression(expected_results_folder: @expected_results_folder)
    begin
      diffs = []


      expected_osm_file = "#{expected_results_folder}#{@model_name}_expected_result.osm"
      test_osm_file = "#{expected_results_folder}#{@model_name}_test_result.osm"
      test_idf_file = "#{expected_results_folder}#{@model_name}_test_result.idf"

      #save test results by default
      BTAP::FileIO.save_osm(@model, test_osm_file)
      puts "saved test result osm file to #{test_osm_file}"
      BTAP::FileIO.save_idf(@model, test_idf_file)
      puts "saved test result idf file to #{test_idf_file}"

      # Load the expected osm
      unless File.exist?(expected_osm_file)
        raise("The initial osm path: #{expected_osm_file} does not exist.")
      end
      expected_osm_model_path = OpenStudio::Path.new(expected_osm_file.to_s)
      # Upgrade version if required.
      version_translator = OpenStudio::OSVersion::VersionTranslator.new
      expected_model = version_translator.loadModel(expected_osm_model_path).get

      # Compare the two models.
      diffs = BTAP::FileIO::compare_osm_files(expected_model, @model)
    rescue => exception
      # Log error/exception and then keep going.
      error = "#{exception.backtrace.first}: #{exception.message} (#{exception.class})"
      exception.backtrace.drop(1).map {|s| "\n#{s}"}.each {|bt| error << bt.to_s}
      diffs << "#{@model_name}: Error \n#{error}"
    end
    #Write out diff or error message
    diff_file = "#{expected_results_folder}#{@model_name}_diffs.json"
    FileUtils.rm(diff_file) if File.exists?(diff_file)
    if diffs.size > 0
      File.write(diff_file, JSON.pretty_generate(diffs))
      puts "There were #{diffs.size} differences/errors in #{expected_osm_file} #{@template} #{@epw_file}"
      return false, {"diffs-errors" => diffs}
    else
      return true, []
    end
  end

  # This method applies 20 space types to 20 spaces of a model. Space types are determined
  # from the iteration argument, and a test_sets file.
  def apply_spacetype_iteration_to_model(model: @model, iteration: int, template: @template)
    # Remove space types in model
    model.getSpaceTypes.each do |space_type|
      space_type.remove
    end

    # Get NECB space_types names
    spacetypes_paths = {
      "NECB2011"=> "test/necb/building_regression_tests/resources/space_types_data/NECB2011-space-type-names.json",
      "NECB2015"=> "test/necb/building_regression_tests/resources/space_types_data/NECB2015-space-type-names.json",
      "NECB2017"=> "test/necb/building_regression_tests/resources/space_types_data/NECB2017-space-type-names.json",
      "NECB2020"=> "test/necb/building_regression_tests/resources/space_types_data/NECB2020-space-type-names.json"
    }

    spacetype_names_data = File.read(spacetypes_paths[template])
    spacetype_names_hash = JSON.parse(spacetype_names_data)
    spacetype_names_arr = spacetype_names_hash["Space Function"]
    spacetype_names_arr = spacetype_names_arr.sort

    # Add NECB space types to model
    building_type = "Space Function"
    standards_template = template
    spacetype_names_arr.each do |space_type_name|
      new_space_type = OpenStudio::Model::SpaceType.new(model)
      new_space_type.setName("#{building_type} #{space_type_name}")
      new_space_type.setStandardsBuildingType("#{building_type}")
      new_space_type.setStandardsSpaceType("#{space_type_name}")
      new_space_type.setStandardsTemplate("#{standards_template}")
    end

    # Fetch test sets information from json file

    test_set_paths = {
      "NECB2011"=> "test/necb/building_regression_tests/resources/space_types_data/NECB2011-test-set-buffer-size-6.json",
      "NECB2015"=> "test/necb/building_regression_tests/resources/space_types_data/NECB2015-test-set-buffer-size-6.json",
      "NECB2017"=> "test/necb/building_regression_tests/resources/space_types_data/NECB2017-test-set-buffer-size-6.json",
      "NECB2020"=> "test/necb/building_regression_tests/resources/space_types_data/NECB2020-test-set-buffer-size-6.json"
    }
    test_set_data = File.read(test_set_paths[template])

    # test_set_file = "test/necb/building_regression_tests/resources/space_types_data/NECB2011-test-set-buffer-size-6.json"
    # test_set_data = File.read(test_set_file)
    test_set_hash = JSON.parse(test_set_data)

    # Create test set matrix from hash created by json.parse, then sort for consistency.
    test_sets = []
    test_set_hash.each do |key, val|
      test_sets.push(val.sort)
    end


    # Iterate through spaces, and assign them correct space type. Note that spaces are sorted for consistency.
    spacetype_index = 0
    model.getSpaces.sort.each do |space|
      # Get spacetype name as it would be in OS from test_set data.
      st_name_temp = "Space Function " + test_sets[iteration][spacetype_index]
      # Find spacetype in model from test set
      model.getSpaceTypes.each do |space_type|
        if space_type.name.get == st_name_temp
          # Apply spacetype to space
          space.setSpaceType(space_type)
        end
      end
      spacetype_index += 1
    end
    return true
  end

  def run_simulation(expected_results_folder: @expected_results_folder)
    model_out_path = "#{@run_dir}/ExampleModel.osm"
    workspace_path = "#{@run_dir}/ModelToIdf/in.idf"
    sql_path = "#{@run_dir}/ModelToIdf/EnergyPlusPreProcess-0/EnergyPlus-0/eplusout.sql"
    report_path = "#{@run_dir}/report.html"
    test_qaqc_file = "#{expected_results_folder}#{@model_name}_test_result_qaqc.json"
    [model_out_path, workspace_path, sql_path, report_path, test_qaqc_file].each do |file|
      if File.exist?(file)
        FileUtils.rm(file)
      end
    end

    BTAP::Environment::WeatherFile.new(@epw_file).set_weather_file(@model)
    Standard.build("#{@template}").model_run_simulation_and_log_errors(@model, @run_dir)
  end


end