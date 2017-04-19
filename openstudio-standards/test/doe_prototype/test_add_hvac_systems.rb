require_relative '../helpers/minitest_helper'

class TestAddHVACSystems < Minitest::Test

  def test_add_hvac_systems

    # Make the output directory if it doesn't exist
    output_dir = File.expand_path('output', File.dirname(__FILE__))
    FileUtils.mkdir output_dir unless Dir.exist? output_dir

    # List all the HVAC system types to test
    hvac_systems = [

      # Gas, Electric, forced air
      ['PTAC', 'NaturalGas', nil, 'Electricity'],
      ['PSZ-AC', 'NaturalGas', nil, 'Electricity'],
      ['PVAV Reheat', 'NaturalGas', 'NaturalGas', 'Electricity'],
      ['VAV Reheat', 'NaturalGas', 'NaturalGas', 'Electricity'],

      # Electric, Electric, forced air
      ['PTHP', 'Electricity', nil, 'Electricity'],
      ['PSZ-HP', 'Electricity', nil, 'Electricity'],
      ['PVAV PFP Boxes', 'Electricity', 'Electricity', 'Electricity'],
      ['VAV PFP Boxes', 'Electricity', 'Electricity', 'Electricity'],

      # District Hot Water, Electric, forced air
      ['PTAC', 'DistrictHeating', nil, 'Electricity'],
      ['PVAV Reheat', 'DistrictHeating', 'DistrictHeating', 'Electricity'],
      ['VAV Reheat', 'DistrictHeating', 'DistrictHeating', 'Electricity'],

      # Ambient Loop, Ambient Loop, forced air
      # TODO make sure ambient loop configurations work
      ['Water Source Heat Pumps with ERVs', 'HeatPump', nil, 'HeatPump'],
      ['Water Source Heat Pumps with DOAS', 'HeatPump', nil, 'HeatPump'],
      ['PVAV Reheat', 'HeatPump', 'HeatPump', 'HeatPump'],
      ['VAV Reheat', 'HeatPump', 'HeatPump', 'HeatPump'],

      # Gas, District Chilled Water, forced air
      ['PTAC', 'NaturalGas', nil, 'DistrictCooling'],
      ['PSZ-AC', 'NaturalGas', nil, 'DistrictCooling'],
      ['PVAV Reheat', 'NaturalGas', 'NaturalGas', 'DistrictCooling'],
      ['VAV Reheat', 'NaturalGas', 'NaturalGas', 'DistrictCooling'],

      # Electric, District Chilled Water, forced air
      ['PTAC', 'Electricity', nil, 'DistrictCooling'],
      ['PSZ-AC', 'Electricity', nil, 'DistrictCooling'],
      ['PVAV Reheat', 'Electricity', 'Electricity', 'DistrictCooling'],
      ['VAV Reheat', 'Electricity', 'Electricity', 'DistrictCooling'],

      # District Hot Water, District Chilled Water, forced air
      ['PTAC', 'DistrictHeating', nil, 'DistrictCooling'],
      ['PVAV Reheat', 'DistrictHeating', 'DistrictHeating', 'DistrictCooling'],
      ['VAV Reheat', 'DistrictHeating', 'DistrictHeating', 'DistrictCooling']
    ]

    template = '90.1-2013'

    # Add each HVAC system to the test model
    # and run a sizing run to ensure it simulates.
    i = 0
    errs = []
    hvac_systems.sort.each do |system_type, main_heat_fuel, zone_heat_fuel, cool_fuel|
      i += 1
      # next if i < 13
      
      reset_log

      type_desc = "#{system_type} #{main_heat_fuel} #{zone_heat_fuel} #{cool_fuel}" 
      puts "running #{type_desc}"

      # Load the test model
      model = safe_load_model("#{File.dirname(__FILE__)}/models/basic_2_story_office_no_hvac.osm")

      # Assign a weather file
      model.add_design_days_and_weather_file('MediumOffice', template, 'ASHRAE 169-2006-7A', '')

      # Add the HVAC
      model.add_hvac_system(template, system_type, main_heat_fuel, zone_heat_fuel, cool_fuel, model.getThermalZones)

      # Save the model
      model_dir = "#{output_dir}/hvac_#{system_type}_#{main_heat_fuel}_#{zone_heat_fuel}_#{cool_fuel}"
      FileUtils.mkdir output_dir unless Dir.exist? output_dir
      model.save("#{model_dir}/final.osm", true)

      # Run the sizing run
      annual_run_success = model.run_simulation_and_log_errors("#{model_dir}/AR")

      # Log the errors
      log_messages_to_file("#{model_dir}/openstudio-standards.log", debug=false)

      errs << "For #{type_desc} annual run failed" unless annual_run_success

      # Check the conditioned floor area
      errs << "For #{type_desc} there was no conditioned area." if model.net_conditioned_floor_area == 0

      # Check the unmet hours
      unmet_hrs = model.annual_occupied_unmet_hours
      max_unmet_hrs = 300
      errs << "For #{type_desc} there were #{unmet_hrs} unmet occupied heating and cooling hours, more than the limit of #{max_unmet_hrs}." if unmet_hrs > max_unmet_hrs

    end
  
    assert(errs.size == 0, errs.join(', '))

    return true
  end
end
