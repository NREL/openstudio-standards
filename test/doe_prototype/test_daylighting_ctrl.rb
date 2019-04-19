require_relative '../helpers/minitest_helper'
require_relative '../helpers/create_doe_prototype_helper'

class TestDaylighting_Ctrl < CreateDOEPrototypeBuildingTest

  def self.model_test(template, building_type, climate_zone)
    epw_file = 'USA_FL_Miami.Intl.AP.722020_TMY3.epw'
    @test_dir = "#{Dir.pwd}/output"
    if !Dir.exists?(@test_dir)
      Dir.mkdir(@test_dir)
    end
    model_name = "#{building_type}-#{template}-#{climate_zone}"
    run_dir = "#{@test_dir}/#{model_name}"
    if !Dir.exists?(run_dir)
        Dir.mkdir(run_dir)
    end
    prototype_creator = Standard.build("#{template}_#{building_type}")
    model = prototype_creator.model_create_prototype_model(climate_zone, epw_file, run_dir)
    osm_path_string = "#{run_dir}/#{model_name}.osm"
    osm_path = OpenStudio::Path.new(osm_path_string)
    idf_path_string = "#{run_dir}/#{model_name}.idf"
    idf_path = OpenStudio::Path.new(idf_path_string)
    model.save(osm_path, true)
    forward_translator = OpenStudio::EnergyPlus::ForwardTranslator.new
    idf = forward_translator.translateModel(model)
    idf.save(idf_path,true)

    return model
  end

  def test_daylighting_ctrl
    # Small Office
    template = '90.1-2010'
    building_type = 'SmallOffice'
    climate_zone = 'ASHRAE 169-2013-1A'
    model = TestDaylighting_Ctrl.model_test(template, building_type, climate_zone)
    true_daylght_ctrl = {"Perimeter_ZN_3 Daylt Sensor 2" => [24.3664, 16.8598, 0.762],
                         "Perimeter_ZN_1 Daylt Sensor 1" => [3.3236, 1.6002, 0.762],
                         "Perimeter_ZN_4 Daylt Sensor 1" => [1.6002, 15.1364, 0.762],
                         "Perimeter_ZN_2 Daylt Sensor 1" => [26.0898, 3.3236, 0.762],
                         "Perimeter_ZN_1 Daylt Sensor 2" => [8.9611, 1.6002, 0.762],
                         "Perimeter_ZN_2 Daylt Sensor 2" => [24.46608, 6.925, 0.762],
                         "Perimeter_ZN_3 Daylt Sensor 1" => [13.8684, 16.8598, 0.762],
                         "Perimeter_ZN_4 Daylt Sensor 2" => [1.6002, 9.2446, 0.762]}
    model.getDaylightingControls.each do |daylght_ctrl|
      assert([daylght_ctrl.positionXCoordinate.to_f, daylght_ctrl.positionYCoordinate.to_f, daylght_ctrl.positionZCoordinate.to_f] == true_daylght_ctrl[daylght_ctrl.name.to_s], 'Small Office - 2010 - 2A - Sensor Position Incorrect')
    end
    true_daylght_ctrl = {"Perimeter_ZN_1" => [0.02, 0.1],
                         "Attic" => [1.0, 0.0],
                         "Perimeter_ZN_2" => [0.06, 0.15],
                         "Perimeter_ZN_3" => [0.1, 0.02],
                         "Perimeter_ZN_4" => [0.06, 0.15],
                         "Core_ZN"=>[1.0, 0.0]}
    model.getSpaces.each do |space|
      zone = space.thermalZone.get
      assert([zone.getFractionofZoneControlledbyPrimaryDaylightingControl.value, zone.getFractionofZoneControlledbySecondaryDaylightingControl.value] == true_daylght_ctrl[space.name.to_s], 'Small Office - 2010 - 2A - Fraction Incorrect')
    end

    # Small Office
    template = '90.1-2013'
    building_type = 'SmallOffice'
    climate_zone = 'ASHRAE 169-2013-1A'
    model = TestDaylighting_Ctrl.model_test(template, building_type, climate_zone)
    true_daylght_ctrl = {"Perimeter_ZN_3 Daylt Sensor 2" => [18.288, 15.1925, 0.762],
                         "Perimeter_ZN_1 Daylt Sensor 1" => [9.144, 1.6337, 0.762],
                         "Perimeter_ZN_4 Daylt Sensor 1" => [1.6337, 9.144, 0.762],
                         "Perimeter_ZN_2 Daylt Sensor 1" => [26.0898, 9.144, 0.762],
                         "Perimeter_ZN_1 Daylt Sensor 2" => [9.144, 3.2675, 0.762],
                         "Perimeter_ZN_2 Daylt Sensor 2" => [24.4561, 9.144, 0.762],
                         "Perimeter_ZN_3 Daylt Sensor 1" => [18.288, 16.825, 0.762],
                         "Perimeter_ZN_4 Daylt Sensor 2" => [3.2675, 9.144, 0.762]}
    model.getDaylightingControls.each do |daylght_ctrl|
      assert([daylght_ctrl.positionXCoordinate.to_f, daylght_ctrl.positionYCoordinate.to_f, daylght_ctrl.positionZCoordinate.to_f] == true_daylght_ctrl[daylght_ctrl.name.to_s], 'Small Office - 2013 - 2A - Sensor Position Incorrect')
    end
    true_daylght_ctrl = {"Perimeter_ZN_1" => [0.2399, 0.0302],
                         "Attic" => [1.0, 0.0],
                         "Perimeter_ZN_2" => [0.2399, 0.0302],
                         "Perimeter_ZN_3" => [0.2399, 0.0302],
                         "Perimeter_ZN_4" => [0.2399, 0.0302],
                         "Core_ZN"=>[1.0, 0.0]}
    model.getSpaces.each do |space|
      zone = space.thermalZone.get
      assert([zone.getFractionofZoneControlledbyPrimaryDaylightingControl.value, zone.getFractionofZoneControlledbySecondaryDaylightingControl.value] == true_daylght_ctrl[space.name.to_s], 'Small Office - 2013 - 2A - Fraction Incorrect')
    end

    # Medium Office
    template = '90.1-2010'
    building_type = 'MediumOffice'
    climate_zone = 'ASHRAE 169-2013-1A'
    model = TestDaylighting_Ctrl.model_test(template, building_type, climate_zone)                        
    true_daylght_ctrl = {"Perimeter_bot_ZN_1  Daylt Sensor 1" => [3.048, 1.524, 0.762],
                         "Perimeter_bot_ZN_1  Daylt Sensor 2" => [24.9555, 1.524, 0.762],
                         "Perimeter_bot_ZN_2  Daylt Sensor 1" => [48.387, 16.6369, 0.762],
                         "Perimeter_bot_ZN_2  Daylt Sensor 2" => [48.387, 3.048, 0.762],
                         "Perimeter_bot_ZN_3  Daylt Sensor 1" => [24.9514, 31.7498, 0.762],
                         "Perimeter_bot_ZN_3  Daylt Sensor 2" => [46.863, 31.7498, 0.762],
                         "Perimeter_bot_ZN_4  Daylt Sensor 1" => [1.524, 16.6369, 0.762],
                         "Perimeter_bot_ZN_4  Daylt Sensor 2" => [1.524, 30.2514, 0.762],
                         "Perimeter_mid_ZN_1  Daylt Sensor 1" => [3.048, 1.524, 0.762],
                         "Perimeter_mid_ZN_1  Daylt Sensor 2" => [24.9555, 1.524, 0.762],
                         "Perimeter_mid_ZN_2  Daylt Sensor 1" => [48.387, 16.6369, 0.762],
                         "Perimeter_mid_ZN_2  Daylt Sensor 2" => [48.387, 3.048, 0.762],
                         "Perimeter_mid_ZN_3  Daylt Sensor 1" => [24.9514, 31.7498, 0.762],
                         "Perimeter_mid_ZN_3  Daylt Sensor 2" => [46.863, 31.7498, 0.762],
                         "Perimeter_mid_ZN_4  Daylt Sensor 1" => [1.524, 16.6369, 0.762],
                         "Perimeter_mid_ZN_4  Daylt Sensor 2" => [1.524, 30.2514, 0.762],
                         "Perimeter_top_ZN_1  Daylt Sensor 1" => [3.048, 1.524, 0.762],
                         "Perimeter_top_ZN_1  Daylt Sensor 2" => [24.9555, 1.524, 0.762],
                         "Perimeter_top_ZN_2  Daylt Sensor 1" => [48.387, 16.6369, 0.762],
                         "Perimeter_top_ZN_2  Daylt Sensor 2" => [48.387, 3.048, 0.762],
                         "Perimeter_top_ZN_3  Daylt Sensor 1" => [24.9514, 31.7498, 0.762],
                         "Perimeter_top_ZN_3  Daylt Sensor 2" => [46.863, 31.7498, 0.762],
                         "Perimeter_top_ZN_4  Daylt Sensor 1" => [1.524, 16.6369, 0.762],
                         "Perimeter_top_ZN_4  Daylt Sensor 2" => [1.524, 30.2514, 0.762]}
    model.getDaylightingControls.each do |daylght_ctrl|
      assert([daylght_ctrl.positionXCoordinate.to_f, daylght_ctrl.positionYCoordinate.to_f, daylght_ctrl.positionZCoordinate.to_f] == true_daylght_ctrl[daylght_ctrl.name.to_s], 'Medium Office - 2010 - 1A - Sensor Position Incorrect')
    end
    true_daylght_ctrl = { "Perimeter_bot_ZN_1" => [0.08, 0.46]
                          "Perimeter_bot_ZN_2" => [0.43, 0.12]
                          "Perimeter_bot_ZN_3" => [0.46, 0.08]
                          "Perimeter_bot_ZN_4" => [0.43, 0.12]
                          "Perimeter_mid_ZN_1" => [0.08, 0.46]
                          "Perimeter_mid_ZN_2" => [0.43, 0.12]
                          "Perimeter_mid_ZN_3" => [0.46, 0.08]
                          "Perimeter_mid_ZN_4" => [0.43, 0.12]
                          "Perimeter_top_ZN_1" => [0.08, 0.46]
                          "Perimeter_top_ZN_2" => [0.43, 0.12]
                          "Perimeter_top_ZN_3" => [0.46, 0.08]
                          "Perimeter_top_ZN_4" => [0.43, 0.12]}                             
    model.getSpaces.each do |space|
      zone = space.thermalZone.get
      if true_daylght_ctrl.keys.include? (space.name.to_s)
        assert([zone.getFractionofZoneControlledbyPrimaryDaylightingControl.value, zone.getFractionofZoneControlledbySecondaryDaylightingControl.value] == true_daylght_ctrl[space.name.to_s], 'Small Office - 2010 - 2A - Fraction Incorrect')
      end
    end

    # Medium Office
    template = '90.1-2013'
    building_type = 'MediumOffice'
    climate_zone = 'ASHRAE 169-2013-1A'
    model = TestDaylighting_Ctrl.model_test(template, building_type, climate_zone)                        
    true_daylght_ctrl = {"Perimeter_bot_ZN_1  Daylt Sensor 1" => [24.9555, 1.524, 0.762],
                         "Perimeter_bot_ZN_1  Daylt Sensor 2" => [3.048, 1.524, 0.762],
                         "Perimeter_bot_ZN_2  Daylt Sensor 1" => [48.387, 16.6369, 0.762],
                         "Perimeter_bot_ZN_2  Daylt Sensor 2" => [46.863, 16.6369, 0.762],
                         "Perimeter_bot_ZN_3  Daylt Sensor 1" => [24.9555, 31.7498, 0.762],
                         "Perimeter_bot_ZN_3  Daylt Sensor 2" => [24.9555, 30.2258, 0.762],
                         "Perimeter_bot_ZN_4  Daylt Sensor 1" => [1.524, 16.6369, 0.762],
                         "Perimeter_bot_ZN_4  Daylt Sensor 2" => [1.524, 30.2514, 0.762],
                         "Perimeter_mid_ZN_1  Daylt Sensor 1" => [24.9555, 1.524, 0.762],
                         "Perimeter_mid_ZN_1  Daylt Sensor 2" => [3.048, 1.524, 0.762],
                         "Perimeter_mid_ZN_2  Daylt Sensor 1" => [48.387, 16.6369, 0.762],
                         "Perimeter_mid_ZN_2  Daylt Sensor 2" => [46.863, 16.6369, 0.762],
                         "Perimeter_mid_ZN_3  Daylt Sensor 1" => [24.9555, 31.7498, 0.762],
                         "Perimeter_mid_ZN_3  Daylt Sensor 2" => [24.9555, 30.2258, 0.762],
                         "Perimeter_mid_ZN_4  Daylt Sensor 1" => [1.524, 16.6369, 0.762],
                         "Perimeter_mid_ZN_4  Daylt Sensor 2" => [1.524, 30.2514, 0.762],
                         "Perimeter_top_ZN_1  Daylt Sensor 1" => [24.9555, 1.524, 0.762],
                         "Perimeter_top_ZN_1  Daylt Sensor 2" => [3.048, 1.524, 0.762],
                         "Perimeter_top_ZN_2  Daylt Sensor 1" => [48.387, 16.6369, 0.762],
                         "Perimeter_top_ZN_2  Daylt Sensor 2" => [46.863, 16.6369, 0.762],
                         "Perimeter_top_ZN_3  Daylt Sensor 1" => [24.9555, 31.7498, 0.762],
                         "Perimeter_top_ZN_3  Daylt Sensor 2" => [24.9555, 30.2258, 0.762],
                         "Perimeter_top_ZN_4  Daylt Sensor 1" => [1.524, 16.6369, 0.762],
                         "Perimeter_top_ZN_4  Daylt Sensor 2" => [1.524, 30.2514, 0.762],}
    model.getDaylightingControls.each do |daylght_ctrl|
      assert([daylght_ctrl.positionXCoordinate.to_f, daylght_ctrl.positionYCoordinate.to_f, daylght_ctrl.positionZCoordinate.to_f] == true_daylght_ctrl[daylght_ctrl.name.to_s], 'Medium Office - 2013 - 1A - Sensor Position Incorrect')
    end
    true_daylght_ctrl = { "Perimeter_bot_ZN_1" => [0.3835, 0.1395]
                          "Perimeter_bot_ZN_2" => [0.3835, 0.1395]
                          "Perimeter_bot_ZN_3" => [0.3835, 0.1395]
                          "Perimeter_bot_ZN_4" => [0.3835, 0.1395]
                          "Perimeter_mid_ZN_1" => [0.3835, 0.1395]
                          "Perimeter_mid_ZN_2" => [0.3835, 0.1395]
                          "Perimeter_mid_ZN_3" => [0.3835, 0.1395]
                          "Perimeter_mid_ZN_4" => [0.3835, 0.1395]
                          "Perimeter_top_ZN_1" => [0.3835, 0.1395]
                          "Perimeter_top_ZN_2" => [0.3835, 0.1395]
                          "Perimeter_top_ZN_3" => [0.3835, 0.1395]
                          "Perimeter_top_ZN_4" => [0.3835, 0.1395]}                             
    model.getSpaces.each do |space|
      zone = space.thermalZone.get
      if true_daylght_ctrl.keys.include? (space.name.to_s)
        assert([zone.getFractionofZoneControlledbyPrimaryDaylightingControl.value, zone.getFractionofZoneControlledbySecondaryDaylightingControl.value] == true_daylght_ctrl[space.name.to_s], 'Small Office - 2013 - 2A - Fraction Incorrect')
      end
    end
  end
end