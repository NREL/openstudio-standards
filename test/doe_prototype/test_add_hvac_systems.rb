require_relative '../helpers/minitest_helper'

class TestAddHVACSystems < Minitest::Test

  def test_add_hvac_systems

    # Make the output directory if it doesn't exist
    output_dir = File.expand_path('output', File.dirname(__FILE__))
    FileUtils.mkdir output_dir unless Dir.exist? output_dir

    # List all the HVAC system types to test
    hvac_systems = [

        ## Forced Air ##

        # Gas, Electric, forced air
        ['PTAC', 'NaturalGas', nil, 'Electricity'],
        ['PSZ-AC', 'NaturalGas', nil, 'Electricity'],
        # ['PVAV Reheat', 'NaturalGas', 'NaturalGas', 'Electricity'], # Disable this; failure due to bug in E+ 8.8 w/ VAV terminal min airflow sizing
        ['VAV Reheat', 'NaturalGas', 'NaturalGas', 'Electricity'],

        # Electric, Electric, forced air
        ['PTHP', 'Electricity', nil, 'Electricity'],
        ['PSZ-HP', 'Electricity', nil, 'Electricity'],
        ['PVAV PFP Boxes', 'Electricity', 'Electricity', 'Electricity'],
        ['VAV PFP Boxes', 'Electricity', 'Electricity', 'Electricity'],

        # District Hot Water, Electric, forced air
        ['PTAC', 'DistrictHeating', nil, 'Electricity'],
        # ['PVAV Reheat', 'DistrictHeating', 'DistrictHeating', 'Electricity'], # Disable this; failure due to bug in E+ 8.8 w/ VAV terminal min airflow sizing
        ['VAV Reheat', 'DistrictHeating', 'DistrictHeating', 'Electricity'],

        # Ambient Loop, Ambient Loop, forced air
        # ['PVAV Reheat', 'HeatPump', 'HeatPump', 'HeatPump'],
        # ['VAV Reheat', 'HeatPump', 'HeatPump', 'HeatPump'],

        # Gas, District Chilled Water, forced air
        ['PSZ-AC', 'NaturalGas', nil, 'DistrictCooling'],
        ['PVAV Reheat', 'NaturalGas', 'NaturalGas', 'DistrictCooling'],
        ['VAV Reheat', 'NaturalGas', 'NaturalGas', 'DistrictCooling'],

        # Electric, District Chilled Water, forced air
        ['PSZ-AC', 'Electricity', nil, 'DistrictCooling'],
        ['PVAV Reheat', 'Electricity', 'Electricity', 'DistrictCooling'],
        ['VAV Reheat', 'Electricity', 'Electricity', 'DistrictCooling'],

        # District Hot Water, District Chilled Water, forced air
        ['PVAV Reheat', 'DistrictHeating', 'DistrictHeating', 'DistrictCooling'],
        ['VAV Reheat', 'DistrictHeating', 'DistrictHeating', 'DistrictCooling'],

        ## Hydronic ##

        # Gas, Electric, hydronic
        ['Fan Coil with DOAS', 'NaturalGas', nil, 'Electricity'],
        ['Water Source Heat Pumps with DOAS', 'NaturalGas', nil, 'Electricity'],
        ['Fan Coil with DOAS', 'NaturalGas', 'NaturalGas', 'Electricity'],

        # Electric, Electric, hydronic
        ['Ground Source Heat Pumps with ERVs', 'Electricity', nil, 'Electricity'],
        ['Ground Source Heat Pumps with DOAS', 'Electricity', nil, 'Electricity'],
        ['Ground Source Heat Pumps with DOAS', 'Electricity', 'Electricity', 'Electricity'],

        # District Hot Water, Electric, hydronic
        ['Fan Coil with DOAS', 'DistrictHeating', nil, 'Electricity'],
        ['Water Source Heat Pumps with DOAS', 'DistrictHeating', 'DistrictHeating', 'Electricity'],
        ['Fan Coil with DOAS', 'DistrictHeating', 'DistrictHeating', 'Electricity'],

        # Ambient Loop, Ambient Loop, hydronic
        ['Water Source Heat Pumps with ERVs', 'HeatPump', nil, 'HeatPump'],
        ['Water Source Heat Pumps with DOAS', 'HeatPump', nil, 'HeatPump'],
        ['Water Source Heat Pumps with DOAS', 'HeatPump', 'HeatPump', 'HeatPump'],

        # Gas, District Chilled Water, hydronic
        ['Fan Coil with DOAS', 'NaturalGas', nil, 'DistrictCooling'],
        ['Fan Coil with DOAS', 'NaturalGas', 'NaturalGas', 'DistrictCooling'],

        # Electric, District Chilled Water, hydronic
        ['Fan Coil with ERVs', 'Electricity', nil, 'DistrictCooling'],
        ['Fan Coil with DOAS', 'Electricity', 'Electricity', 'DistrictCooling'],

        # District Hot Water, District Chilled Water, hydronic
        ['Fan Coil with ERVs', 'DistrictHeating', nil, 'DistrictCooling'],
        ['Fan Coil with DOAS', 'DistrictHeating', nil, 'DistrictCooling'],
        ['Fan Coil with DOAS', 'DistrictHeating', 'DistrictHeating', 'DistrictCooling']
    ]

    template = '90.1-2013'
    standard = Standard.build(template)

    # Add each HVAC system to the test model
    # and run a sizing run to ensure it simulates.
    i = 0
    errs = []
    hvac_systems.each do |system_type, main_heat_fuel, zone_heat_fuel, cool_fuel|
      i += 1
      # next if i < 13

      reset_log

      type_desc = "#{system_type} #{main_heat_fuel} #{zone_heat_fuel} #{cool_fuel}"
      puts "running #{type_desc}"

      model_dir = "#{output_dir}/hvac_#{system_type}_#{main_heat_fuel}_#{zone_heat_fuel}_#{cool_fuel}"
      # Load the model if already created
      if File.exist?("#{model_dir}/final.osm")

        model = OpenStudio::Model::Model.new
        sql = standard.safe_load_sql("#{model_dir}/AR/run/eplusout.sql")
        model.setSqlFile(sql)

        # If not created, make and run annual simulation
      else

        # Load the test model
        model = standard.safe_load_model("#{File.dirname(__FILE__)}/models/basic_2_story_office_no_hvac.osm")

        # Assign a weather file
        standard.model_add_design_days_and_weather_file(model, 'ASHRAE 169-2006-7A', '')
        standard.model_add_ground_temperatures(model, 'MediumOffice', 'ASHRAE 169-2006-7A')
        # Add the HVAC
        standard.model_add_hvac_system(model, system_type, main_heat_fuel, zone_heat_fuel, cool_fuel, model.getThermalZones)

        # Save the model
        model.save("#{model_dir}/final.osm", true)

        # Run the sizing run
        annual_run_success = standard.model_run_simulation_and_log_errors(model, "#{model_dir}/AR")

        # Log the errors
        log_messages_to_file("#{model_dir}/openstudio-standards.log", debug=false)

        errs << "For #{type_desc} annual run failed" unless annual_run_success

      end

      # Check the conditioned floor area
      errs << "For #{type_desc} there was no conditioned area." if standard.model_net_conditioned_floor_area(model) == 0

      # Check the unmet hours
      unmet_hrs = standard.model_annual_occupied_unmet_hours(model)
      max_unmet_hrs = 550
      if unmet_hrs
        errs << "For #{type_desc} there were #{unmet_hrs} unmet occupied heating and cooling hours, more than the limit of #{max_unmet_hrs}." if unmet_hrs > max_unmet_hrs
      else
        errs << "For #{type_desc} could not determine unmet hours; simulation may have failed."
      end
    end

    assert(errs.size == 0, errs.join("\n"))

    return true
  end
end