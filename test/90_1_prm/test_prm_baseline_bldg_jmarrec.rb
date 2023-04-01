require_relative '../helpers/minitest_helper'
require_relative 'create_performance_rating_method_helper'

class CreatePerformanceRatingMethodBaselineBuildingTest < Minitest::Test

  def test_jmarrec

    model_name = 'model'
    standard = '90.1-2007'
    climate_zone = 'ASHRAE 169-2013--5A'
    # Use addenda dn (heated only systems)
    custom = '90.1-2007 with addenda dn'
    model = create_baseline_model(model_name, standard, climate_zone, 'MidriseApartment', custom, debug = true, load_existing_model = true)

    # Do another sizing run just to check that the final values are actually correct
    # I realized when testing the pump power that it was fine per the previous sizing run, but the code was actually changing the values again, leading to wrong pumping power
    test_dir = "#{File.dirname(__FILE__)}/output"
    sizing_run_dir = "#{test_dir}/#{model_name}-#{standard}-#{climate_zone}-#{custom}"

    # Run sizing run with the HVAC equipment
    if standard.model_run_sizing_run(model, "#{sizing_run_dir}/SizingRunFinalCheckOnly") == false
      return false
    end

    model.getPlantLoops.each do |loop|

      total_rated_w_per_gpm = plant_loop_total_rated_w_per_gpm(plant_loop)

      loop_type = loop.sizingPlant.loopType

      if loop.is_shw_loop
        OpenStudio::logFree(OpenStudio::Info, 'openstudio.standards.Model', "'#{loop.name}' is a SHW loop with a pump power of #{total_rated_w_per_gpm.round(2)} W/GPM (nothing expected)")
      else
        case loop_type
          when 'Cooling'
            assert_in_delta(22, total_rated_w_per_gpm, 0.1, "'#{loop.name}' of type '#{loop_type}' has a pump power of #{total_rated_w_per_gpm.round(2)} W/GPM when 22 W/GPM was expected")
            OpenStudio::logFree(OpenStudio::Error, 'openstudio.standards.Model', "'#{loop.name}' of type '#{loop_type}' has a pump power of #{total_rated_w_per_gpm.round(2)} W/GPM (22 W/GPM expected)")
          when 'Heating'
            assert_in_delta(19, total_rated_w_per_gpm, 0.1, "'#{loop.name}' of type '#{loop_type}' has a pump power of #{total_rated_w_per_gpm.round(2)} W/GPM when 19 W/GPM was expected")
            OpenStudio::logFree(OpenStudio::Error, 'openstudio.standards.Model', "'#{loop.name}' of type '#{loop_type}' has a pump power of #{total_rated_w_per_gpm.round(2)} W/GPM (19 W/GPM expected)")
          when 'Condenser'
            assert_in_delta(19, total_rated_w_per_gpm, 0.1, "'#{loop.name}' of type '#{loop_type}' has a pump power of #{total_rated_w_per_gpm.round(2)} W/GPM when 19 W/GPM was expected")
            OpenStudio::logFree(OpenStudio::Error, 'openstudio.standards.Model', "'#{loop.name}' of type '#{loop_type}' has a pump power of #{total_rated_w_per_gpm.round(2)} W/GPM (19 W/GPM expected)")
          else
            OpenStudio::logFree(OpenStudio::Error, 'openstudio.standards.Model', "Loop #{loop.name} has a type of '#{loop_type}' that isn't recognized/handled!")
        end
      end

    end


    # Output fan rated w per cfm for each fan
    model.output_fan_report("#{sizing_run_dir}/fan_report.csv")

    sql = model.sqlFile

    if sql.is_initialized
      sql = sql.get

      unmet_heating_hours = sql.hoursHeatingSetpointNotMet.get
      unmet_cooling_hours = sql.hoursCoolingSetpointNotMet.get


      puts "Unmet heating hours: #{unmet_heating_hours}"
      puts "Unmet cooling hours: #{unmet_cooling_hours}"

      assert(unmet_heating_hours<300,"Unmet heating hours are above 300: #{unmet_heating_hours}")
      assert(unmet_cooling_hours<300,"Unmet cooling hours are above 300: #{unmet_cooling_hours}")

    end

  end

  def test_jmarrec_model_iterative

    # Create the baseline model
    #model = create_baseline_model('jmarrec', '90.1-2007', 'ASHRAE 169-2013--4A', 'MediumOffice', false)

    model_name = 'jmarrec'
    standard = '90.1-2007'
    building_vintage = standard
    climate_zone = 'ASHRAE 169-2013--4A'
    building_type = 'MidriseApartment'

    debug=true

    # Make a directory to save the resulting models
    test_dir = "#{File.dirname(__FILE__)}/output"
    if !Dir.exists?(test_dir)
      Dir.mkdir(test_dir)
    end

    # Load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new("#{File.dirname(__FILE__)}/test_models/performance_rating_method/#{model_name}.osm")
    model = translator.loadModel(path)
    assert(model.is_initialized, "Could not load test model '#{model_name}.osm' from test_models/performance_rating_method.  Check name for typos.")
    model = model.get

    # Create a directory for the test result
    osm_directory = "#{test_dir}/#{model_name}-#{standard}-#{climate_zone}"
    if !Dir.exists?(osm_directory)
      Dir.mkdir(osm_directory)
    end

    # Create the baseline model from the
    # supplied proposed test model
    #create_performance_rating_method_baseline_building(building_type, building_vintage, climate_zone, sizing_run_dir = Dir.pwd, debug = false)
    #model.create_performance_rating_method_baseline_building(building_type,standard,climate_zone,osm_directory,debug = false)

    sys_groups = model.performance_rating_method_baseline_system_groups(building_vintage)

    # temp debug
    totZones = 0
    zones = []
    sys_groups.each do |group|
      puts "\n\n============== #{group[:occtype]} - #{group[:fueltype]} =============="
      group[:zones].each do |z|
        puts z.name
        totZones += 1
        zones << z
      end
    end

    puts "Total number of zones classified #{totZones}  in #{sys_groups.size} groups"


    puts "\n\nHere are the termal zones not classified"
    model.getThermalZones.each do |z|
      if !zones.include?(z)
        puts z.name
      end
    end



    
  end


  def test_residential_and_nonresidential_story_counts

    # Make a directory to save the resulting models
    test_dir = "#{File.dirname(__FILE__)}/output"
    if !Dir.exists?(test_dir)
      Dir.mkdir(test_dir)
    end

    model_name = 'jmarrec'
    standard = '90.1-2007'

    # Load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new("#{File.dirname(__FILE__)}/test_models/performance_rating_method/#{model_name}.osm")
    model = translator.loadModel(path)
    assert(model.is_initialized, "Could not load test model '#{model_name}.osm' from test_models/performance_rating_method.  Check name for typos.")
    model = model.get

    stories = model.residential_and_nonresidential_story_counts(standard)

    puts "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
    puts stories


  end


  def test_btap_cleaning

    model_name = 'jmarrec'
    standard = '90.1-2007'

    # Load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new("#{File.dirname(__FILE__)}/test_models/performance_rating_method/#{model_name}.osm")
    model = translator.loadModel(path)
    assert(model.is_initialized, "Could not load test model '#{model_name}.osm' from test_models/performance_rating_method.  Check name for typos.")
    model = model.get

    initial_outdoor_vrf = model.getAirConditionerVariableRefrigerantFlows.size
    initial_zone_vrf = model.getZoneHVACTerminalUnitVariableRefrigerantFlows.size
    puts "Initial outdoor VRF #{initial_outdoor_vrf} and number of indoor #{initial_zone_vrf}"

    # Remove all HVAC from model
    BTAP::Resources::HVAC.clear_all_hvac_from_model(model)

    final_outdoor_vrf = model.getAirConditionerVariableRefrigerantFlows.size
    final_zone_vrf = model.getZoneHVACTerminalUnitVariableRefrigerantFlows.size
    puts "Final outdoor VRF #{final_outdoor_vrf} and number of indoor #{final_zone_vrf}"

    assert_equal(0, model.getAirConditionerVariableRefrigerantFlows.size)
    assert_equal(0, model.getZoneHVACTerminalUnitVariableRefrigerantFlows.size)



  end


  def test_debug_failing_find_constructions

    model_name = 'jmarrec'
    standard = '90.1-2007'

    # Load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new("#{File.dirname(__FILE__)}/test_models/performance_rating_method/#{model_name}.osm")
    model = translator.loadModel(path)
    assert(model.is_initialized, "Could not load test model '#{model_name}.osm' from test_models/performance_rating_method.  Check name for typos.")
    model = model.get

    boundary_cond = 'Outdoors'
    surf_type = 'ExteriorWall'
    model_find_constructions(model, boundary_cond, surf_type)
    # Minitest::UnexpectedError: ArgumentError: comparison of OpenStudio::Model::OptionalConstructionBase with OpenStudio::Model::OptionalConstructionBase failed




  end



end
