require_relative 'minitest_helper'
require_relative 'create_performance_rating_method_helper'

class CreatePerformanceRatingMethodBaselineBuildingTest < Minitest::Test


  def test_jmarrec

    model = create_baseline_model('jmarrec', '90.1-2007', 'ASHRAE 169-2006-4A', 'MediumOffice', false)

  end

  def test_jmarrec_model_iterative

    # Create the baseline model
    #model = create_baseline_model('jmarrec', '90.1-2007', 'ASHRAE 169-2006-4A', 'MediumOffice', false)

    model_name = 'jmarrec'
    standard = '90.1-2007'
    building_vintage = standard
    climate_zone = 'ASHRAE 169-2006-4A'
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
    model.find_constructions(boundary_cond, surf_type)
    # Minitest::UnexpectedError: ArgumentError: comparison of OpenStudio::Model::OptionalConstructionBase with OpenStudio::Model::OptionalConstructionBase failed




  end



end