require_relative '../helpers/minitest_helper'
require_relative 'create_performance_rating_method_helper'
require_relative 'baseline_901_2013_helper'

class Baseline9012013TestBldg12 < Minitest::Test

  include Baseline9012013

  # @author Matt Steen, Eric Ringold, Ambient Energy
  def test_bldg_12_shw

    test_model_name = 'bldg_12'
    building_type = 'MidriseApartment'
    climate_zone = 'ASHRAE 169-2006-5B'
    
    base_model = create_baseline_model(test_model_name, '90.1-2013', climate_zone, building_type,'Xcel Energy CO EDA', false, true)
    prop_model = load_test_model(test_model_name)
    
    check_shw(base_model, prop_model,building_type)   
    
  end
  
  # @author Matt Steen, Eric Ringold, Ambient Energy
  def test_bldg_12_baseline_sys

    test_model_name = 'bldg_12'
    building_type = 'MidriseApartment'
    climate_zone = 'ASHRAE 169-2006-5B'
    
    base_model = create_baseline_model(test_model_name, '90.1-2013', climate_zone, building_type,'Xcel Energy CO EDA', false, true)

    # Check for PTAC in the apartments
    ['2-3F E Apt West', '4F W Apt Studio North'].each do |zone_name|
      zone = base_model.getThermalZoneByName(zone_name).get
      zone.equipment.each do |equip|
        next if equip.to_FanZoneExhaust.is_initialized
        assert(equip.to_ZoneHVACPackagedTerminalAirConditioner.is_initialized, "Apartment HVAC is not correct, it should be a PTAC.")
      end
    end
    
  end

  # @author Matt Steen, Eric Ringold, Ambient Energy
  def test_bldg_12_num_boilers

    test_model_name = 'bldg_12'
    
    base_model = create_baseline_model(test_model_name, '90.1-2013', 'ASHRAE 169-2006-5B', 'MidriseApartment','Xcel Energy CO EDA', false, true)
    prop_model = load_test_model(test_model_name)
    
    check_num_boilers(base_model, prop_model)
    
  end  
  
  # @author Matt Steen, Eric Ringold, Ambient Energy
  def test_bldg_12_num_chillers

    test_model_name = 'bldg_12'
    
    base_model = create_baseline_model(test_model_name, '90.1-2013', 'ASHRAE 169-2006-5B', 'MidriseApartment','Xcel Energy CO EDA', false, true)
    prop_model = load_test_model(test_model_name)
    
    check_num_chillers(base_model, prop_model)
    
  end   

  # @author Matt Steen, Eric Ringold, Ambient Energy
  def test_bldg_12_plant_controls

    test_model_name = 'bldg_12'
    
    base_model = create_baseline_model(test_model_name, '90.1-2013', 'ASHRAE 169-2006-5B', 'MidriseApartment','Xcel Energy CO EDA', false, true)
    prop_model = load_test_model(test_model_name)
    
    check_plant_controls(base_model, prop_model)
    
  end

end
