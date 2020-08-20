require_relative '../helpers/minitest_helper'

class TestAddHVACSystems < Minitest::Test

  def setup()
    super()

    # Make the output directory if it doesn't exist
    @output_dir = File.expand_path('output', File.dirname(__FILE__))
    FileUtils.mkdir(@output_dir) unless Dir.exist?(@output_dir)
    puts @output_dir

    # example hash for an HVAC system type test
    # default optional arguments should match those in model_add_hvac_system
    @default_hash = {model_name: 'basic_2_story_office_no_hvac_60WWR', climate_zone: 'ASHRAE 169-2013-7A',
                     unmet_hrs_htg: 300.0, unmet_hrs_clg: 300.0,
                     system_type: nil, main_heat_fuel: nil, zone_heat_fuel: nil, cool_fuel: nil,
                     hot_water_loop_type: 'HighTemperature',
                     chilled_water_loop_cooling_type: 'WaterCooled',
                     heat_pump_loop_cooling_type: 'EvaporativeFluidCooler',
                     air_loop_heating_type: 'Water',
                     air_loop_cooling_type: 'Water',
                     zone_equipment_ventilation: true}
    @template = '90.1-2013'
    @standard = Standard.build(@template)
  end

  def test_gas_elec_forced_air_hvac()
    # List all the HVAC system types to test
    hvac_systems = [
        ## Forced Air ##
        # Gas, Electric, forced air
        {system_type: 'PTAC', main_heat_fuel: 'NaturalGas', zone_heat_fuel: nil, cool_fuel: 'Electricity'},
        {system_type: 'PSZ-AC', main_heat_fuel: 'NaturalGas', zone_heat_fuel: nil, cool_fuel: 'Electricity'},
        {system_type: 'PSZ-VAV', main_heat_fuel: 'NaturalGas', zone_heat_fuel: 'NaturalGas', cool_fuel: 'Electricity'},
        {system_type: 'PVAV Reheat', main_heat_fuel: 'NaturalGas', zone_heat_fuel: 'NaturalGas', cool_fuel: 'Electricity',
         unmet_hrs_htg: 650.0},
        {system_type: 'VAV Reheat', main_heat_fuel: 'NaturalGas', zone_heat_fuel: 'NaturalGas', cool_fuel: 'Electricity',
         unmet_hrs_htg: 450.0}
    ]
    add_hvac(hvac_systems: hvac_systems)
  end

  def test_elec_elec_forced_air_hvac()
    # List all the HVAC system types to test
    hvac_systems = [
        # Electric, Electric, forced air
        {system_type: 'PTHP', main_heat_fuel: 'Electricity', zone_heat_fuel: nil, cool_fuel: 'Electricity'},
        {system_type: 'PSZ-HP', main_heat_fuel: 'Electricity', zone_heat_fuel: nil, cool_fuel: 'Electricity'},
        {system_type: 'PVAV PFP Boxes', main_heat_fuel: 'Electricity', zone_heat_fuel: 'Electricity', cool_fuel: 'Electricity'},
        {system_type: 'VAV PFP Boxes', main_heat_fuel: 'Electricity', zone_heat_fuel: 'Electricity', cool_fuel: 'Electricity'}
    ]
    add_hvac(hvac_systems: hvac_systems)
  end

  def test_elec_elec_forced_air_hvac()
    # List all the HVAC system types to test
    hvac_systems = [
        # District Hot Water, Electric, forced air
        {system_type: 'PTAC', main_heat_fuel: 'DistrictHeating', zone_heat_fuel: nil, cool_fuel: 'Electricity'},
        {system_type: 'PVAV Reheat', main_heat_fuel: 'DistrictHeating', zone_heat_fuel: 'DistrictHeating', cool_fuel: 'Electricity',
         unmet_hrs_htg: 650.0},
        {system_type: 'VAV Reheat', main_heat_fuel: 'DistrictHeating', zone_heat_fuel: 'DistrictHeating', cool_fuel: 'Electricity',
         unmet_hrs_htg: 450.0}]
    add_hvac(hvac_systems: hvac_systems)
  end


  def test_central_ashp_forced_air_hvac()
    # List all the HVAC system types to test
    hvac_systems = [
        # Central Air Source Heat Pump plant object, forced air
        {system_type: 'VAV Reheat', main_heat_fuel: 'AirSourceHeatPump', zone_heat_fuel: 'AirSourceHeatPump', cool_fuel: 'Electricity'}
    ]
    add_hvac(hvac_systems: hvac_systems)
  end

  def test_ambiant_loop_ambiant_loop_forced_air_hvac()
    # List all the HVAC system types to test
    hvac_systems = [
        # Ambient Loop, Ambient Loop, forced air
        {system_type: 'PVAV Reheat', main_heat_fuel: 'HeatPump', zone_heat_fuel: 'HeatPump', cool_fuel: 'HeatPump',
         unmet_hrs_htg: 650.0},
        {system_type: 'VAV Reheat', main_heat_fuel: 'HeatPump', zone_heat_fuel: 'HeatPump', cool_fuel: 'HeatPump',
         unmet_hrs_htg: 650.0}
    ]
    add_hvac(hvac_systems: hvac_systems)
  end


  def test_gas_dist_chilled_water_forced_air_hvac()
    # Gas, District Chilled Water, forced air
    hvac_systems = [
        {system_type: 'PSZ-AC', main_heat_fuel: 'NaturalGas', zone_heat_fuel: nil, cool_fuel: 'DistrictCooling'},
        {system_type: 'PVAV Reheat', main_heat_fuel: 'NaturalGas', zone_heat_fuel: 'NaturalGas', cool_fuel: 'DistrictCooling',
         unmet_hrs_htg: 650.0},
        {system_type: 'VAV Reheat', main_heat_fuel: 'NaturalGas', zone_heat_fuel: 'NaturalGas', cool_fuel: 'DistrictCooling',
         unmet_hrs_htg: 450.0}
    ]
    add_hvac(hvac_systems: hvac_systems)
  end

  def test_district_forced_air_hvac()
    hvac_systems = [
        # Electric, District Chilled Water, forced air
        {system_type: 'PSZ-AC', main_heat_fuel: 'Electricity', zone_heat_fuel: nil, cool_fuel: 'DistrictCooling'},
        # {system_type: 'VAV Reheat', main_heat_fuel: 'Electricity', zone_heat_fuel: 'Electricity', cool_fuel: 'DistrictCooling'},

        # District Hot Water, District Chilled Water, forced air
        {system_type: 'PVAV Reheat', main_heat_fuel: 'DistrictHeating', zone_heat_fuel: 'DistrictHeating', cool_fuel: 'DistrictCooling',
         unmet_hrs_htg: 650.0},
        {system_type: 'VAV Reheat', main_heat_fuel: 'DistrictHeating', zone_heat_fuel: 'DistrictHeating', cool_fuel: 'DistrictCooling',
         unmet_hrs_htg: 450.0}]
    add_hvac(hvac_systems: hvac_systems)
  end

  ## Hydronic ##
  def test_gas_electric_hydronic()
    # Gas, Electric, hydronic
    hvac_systems = [
        {system_type: 'Fan Coil', main_heat_fuel: 'NaturalGas', zone_heat_fuel: nil, cool_fuel: 'Electricity'},
        {system_type: 'Water Source Heat Pumps', main_heat_fuel: 'NaturalGas', zone_heat_fuel: 'NaturalGas', cool_fuel: 'Electricity'},
        {system_type: 'Fan Coil with DOAS', main_heat_fuel: 'NaturalGas', zone_heat_fuel: nil, cool_fuel: 'Electricity',
         zone_equipment_ventilation: false},
        {system_type: 'Fan Coil with DOAS', main_heat_fuel: 'NaturalGas', zone_heat_fuel: 'NaturalGas', cool_fuel: 'Electricity',
         zone_equipment_ventilation: false},
        {system_type: 'Water Source Heat Pumps with DOAS', main_heat_fuel: 'NaturalGas', zone_heat_fuel: 'NaturalGas', cool_fuel: 'Electricity',
         zone_equipment_ventilation: false}]
    add_hvac(hvac_systems: hvac_systems)
  end

  def test_electric_electric_hydronic()

    # Electric, Electric, hydronic
    hvac_systems = [
        {system_type: 'Fan Coil', main_heat_fuel: 'Electricity', zone_heat_fuel: nil, cool_fuel: 'Electricity'},
        {system_type: 'Fan Coil with DOAS', main_heat_fuel: 'Electricity', zone_heat_fuel: nil, cool_fuel: 'Electricity',
         zone_equipment_ventilation: false},
        {system_type: 'Fan Coil with DOAS', main_heat_fuel: 'Electricity', zone_heat_fuel: 'Electricity', cool_fuel: 'Electricity',
         zone_equipment_ventilation: false},
        {system_type: 'Ground Source Heat Pumps with ERVs', main_heat_fuel: 'Electricity', zone_heat_fuel: nil, cool_fuel: 'Electricity',
         zone_equipment_ventilation: false},
        {system_type: 'Ground Source Heat Pumps with DOAS', main_heat_fuel: 'Electricity', zone_heat_fuel: nil, cool_fuel: 'Electricity',
         zone_equipment_ventilation: false},
        {system_type: 'Ground Source Heat Pumps with DOAS', main_heat_fuel: 'Electricity', zone_heat_fuel: 'Electricity', cool_fuel: 'Electricity',
         zone_equipment_ventilation: false}]
    add_hvac(hvac_systems: hvac_systems)

  end

  def test_central_air_ashp_hydronic()

    hvac_systems = [
        # Central Air Source Heat Pump, hydronic
        {system_type: 'Fan Coil with DOAS', main_heat_fuel: 'AirSourceHeatPump', zone_heat_fuel: 'AirSourceHeatPump', cool_fuel: 'Electricity',
         zone_equipment_ventilation: false}]
    add_hvac(hvac_systems: hvac_systems)
  end

  def test_ambiant_loop_ambiant_loop__hydronic()
    # List all the HVAC system types to test
    hvac_systems = [

        # Ambient Loop, Ambient Loop, hydronic
        {system_type: 'Water Source Heat Pumps with DOAS', main_heat_fuel: 'AmbientLoop', zone_heat_fuel: nil, cool_fuel: 'AmbientLoop',
         zone_equipment_ventilation: false},
        # {system_type: 'Water Source Heat Pumps with ERVs', main_heat_fuel: 'AmbientLoop', zone_heat_fuel: nil, cool_fuel: 'AmbientLoop',
        #  zone_equipment_ventilation: false},
    ]
    add_hvac(hvac_systems: hvac_systems)
  end


  def test_district_hydronic()
    hvac_systems = [
        # District Hot Water, District Chilled Water, hydronic
        {system_type: 'Fan Coil with ERVs', main_heat_fuel: 'DistrictHeating', zone_heat_fuel: nil, cool_fuel: 'DistrictCooling',
         zone_equipment_ventilation: false},
        {system_type: 'Fan Coil with DOAS', main_heat_fuel: 'DistrictHeating', zone_heat_fuel: nil, cool_fuel: 'DistrictCooling',
         zone_equipment_ventilation: false},
        {system_type: 'Fan Coil with DOAS', main_heat_fuel: 'DistrictHeating', zone_heat_fuel: 'DistrictHeating', cool_fuel: 'DistrictCooling',
         zone_equipment_ventilation: false}]
    add_hvac(hvac_systems: hvac_systems)
  end

  def test_doas_variants()
    ## DOAS Variations
    hvac_systems = [
        {system_type: 'Fan Coil with DOAS with DCV', main_heat_fuel: 'NaturalGas', zone_heat_fuel: nil, cool_fuel: 'Electricity',
         zone_equipment_ventilation: false}]
    add_hvac(hvac_systems: hvac_systems)
  end

  def test_residential()

    ## Residential Type Systems
    hvac_systems = [
        {system_type: 'Window AC', main_heat_fuel: nil, zone_heat_fuel: nil, cool_fuel: 'Electricity',
         climate_zone: 'ASHRAE 169-2013-2B', unmet_hrs_htg: 3000.0},
        {system_type: 'Residential AC', main_heat_fuel: nil, zone_heat_fuel: nil, cool_fuel: 'Electricity',
         climate_zone: 'ASHRAE 169-2013-2B', unmet_hrs_htg: 3000.0},
        {system_type: 'Residential Forced Air Furnace', main_heat_fuel: 'NaturalGas', zone_heat_fuel: nil, cool_fuel: nil,
         unmet_hrs_clg: 6000.0},
        {system_type: 'Residential Forced Air Furnace with AC', main_heat_fuel: 'NaturalGas', zone_heat_fuel: nil, cool_fuel: 'Electricity'},
        {system_type: 'Residential Air Source Heat Pump', main_heat_fuel: 'Electricity', zone_heat_fuel: nil, cool_fuel: 'Electricity'}]
    add_hvac(hvac_systems: hvac_systems)
  end

  def test_single_zone_and_cooling_only()
    ## Single Zone Heating Only or Cooling Only Systems
    hvac_systems = [
        {system_type: 'Baseboards', main_heat_fuel: 'NaturalGas', zone_heat_fuel: nil, cool_fuel: nil,
         model_name: 'basic_2_story_office_no_hvac_20WWR', unmet_hrs_clg: 6000.0},
        {system_type: 'Unit Heaters', main_heat_fuel: 'NaturalGas', zone_heat_fuel: nil, cool_fuel: nil,
         model_name: 'basic_2_story_office_no_hvac_20WWR', unmet_hrs_clg: 6000.0},
        {system_type: 'High Temp Radiant', main_heat_fuel: 'NaturalGas', zone_heat_fuel: nil, cool_fuel: nil,
         model_name: 'basic_2_story_office_no_hvac_20WWR', unmet_hrs_clg: 6000.0},
    # {system_type: 'Forced Air Furnace', main_heat_fuel: 'NaturalGas', zone_heat_fuel: nil, cool_fuel: nil,
    #  model_name: 'basic_2_story_office_no_hvac_20WWR', unmet_hrs_htg: 1200.0, unmet_hrs_clg: 6000.0},
    # {system_type: 'Evaporative Cooler', main_heat_fuel: nil, zone_heat_fuel: nil, cool_fuel: 'Electricity',
    # climate_zone: 'ASHRAE 169-2013-2B', model_name: 'basic_2_story_office_no_hvac_20WWR'},
    ]
    add_hvac(hvac_systems: hvac_systems)
  end

  def test_special_systems()

    hvac_systems = [
        ## Special System Types
        {system_type: 'Ideal Air Loads', main_heat_fuel: nil, zone_heat_fuel: nil, cool_fuel: nil},
        {system_type: 'VRF', main_heat_fuel: 'Electricity', zone_heat_fuel: nil, cool_fuel: 'Electricity',
         climate_zone: 'ASHRAE 169-2013-4A'},
        {system_type: 'VRF with DOAS', main_heat_fuel: 'Electricity', zone_heat_fuel: nil, cool_fuel: 'Electricity',
         air_loop_heating_type: 'DX', air_loop_cooling_type: 'DX', zone_equipment_ventilation: false,
         climate_zone: 'ASHRAE 169-2013-4A'}
    # {system_type: 'Radiant Slab with DOAS', main_heat_fuel: 'NaturalGas', zone_heat_fuel: nil, cool_fuel: 'Electricity',
        #  hot_water_loop_type: 'LowTemperature', climate_zone: 'ASHRAE 169-2013-5B', model_name: 'basic_2_story_office_no_hvac_20WWR'}
    ]
    add_hvac(hvac_systems: hvac_systems)
  end


  def add_hvac(hvac_systems:)
    errs = []
    hvac_systems.each do |hash|

      reset_log

      hash = @default_hash.merge(hash)
      model_name = hash[:model_name]
      climate_zone = hash[:climate_zone]
      unmet_hrs_htg = hash[:unmet_hrs_htg]
      unmet_hrs_clg = hash[:unmet_hrs_clg]
      system_type = hash[:system_type]
      main_heat_fuel = hash[:main_heat_fuel]
      zone_heat_fuel = hash[:zone_heat_fuel]
      cool_fuel = hash[:cool_fuel]
      hot_water_loop_type = hash[:hot_water_loop_type]
      chilled_water_loop_cooling_type = hash[:chilled_water_loop_cooling_type]
      heat_pump_loop_cooling_type = hash[:heat_pump_loop_cooling_type]
      air_loop_heating_type = hash[:air_loop_heating_type]
      air_loop_cooling_type = hash[:air_loop_cooling_type]
      zone_equipment_ventilation = hash[:zone_equipment_ventilation]

      type_desc = "#{system_type}_#{main_heat_fuel}_#{zone_heat_fuel}_#{cool_fuel}".snake

      model_dir = "#{@output_dir}/hvac_#{type_desc}"

      # Load the model if already created
      if File.exist?("#{model_dir}/final.osm")
        puts "test: '#{type_desc}' results already available. Not re-rerunning energy simulation."
        puts "using: #{model_dir}/final.osm"
        model = OpenStudio::Model::Model.new
        sql = @standard.safe_load_sql("#{model_dir}/AR/run/eplusout.sql")
        model.setSqlFile(sql)
        # If not created, make and run annual simulation
      else
        puts "test: '#{type_desc}' results not available. Running energy simulation."
        # Load the test model
        model = @standard.safe_load_model("#{File.dirname(__FILE__)}/models/#{model_name}.osm")

        # Assign a weather file
        @standard.model_add_design_days_and_weather_file(model, climate_zone, '')
        @standard.model_add_ground_temperatures(model, 'MediumOffice', climate_zone)

        # Add the HVAC
        @standard.model_add_hvac_system(model, system_type, main_heat_fuel, zone_heat_fuel, cool_fuel, model.getThermalZones,
                                        hot_water_loop_type: hot_water_loop_type,
                                        chilled_water_loop_cooling_type: chilled_water_loop_cooling_type,
                                        heat_pump_loop_cooling_type: heat_pump_loop_cooling_type,
                                        air_loop_heating_type: air_loop_heating_type,
                                        air_loop_cooling_type: air_loop_cooling_type,
                                        zone_equipment_ventilation: zone_equipment_ventilation)

        # Save the model
        model.save("#{model_dir}/final.osm", true)

        # Run the sizing run
        annual_run_success = @standard.model_run_simulation_and_log_errors(model, "#{model_dir}/AR")

        # Log the errors
        log_messages_to_file("#{model_dir}/openstudio-standards.log", debug = false)

        errs << "For #{type_desc} annual run failed" unless annual_run_success
      end

      # Check the conditioned floor area
      errs << "For #{type_desc} there was no conditioned area." if @standard.model_net_conditioned_floor_area(model) == 0

      # Check the unmet hours
      unmet_heating_hrs = @standard.model_annual_occupied_unmet_heating_hours(model)
      unmet_cooling_hrs = @standard.model_annual_occupied_unmet_cooling_hours(model)
      unmet_hrs = @standard.model_annual_occupied_unmet_hours(model)
      if unmet_hrs
        if unmet_heating_hrs > unmet_hrs_htg
          errs << "For #{type_desc} there were #{unmet_heating_hrs.round(1)} unmet occupied heating hours, more than the expected limit of #{unmet_hrs_htg}."
        end
        if unmet_cooling_hrs > unmet_hrs_clg
          errs << "For #{type_desc} there were #{unmet_cooling_hrs.round(1)} unmet occupied cooling hours, more than the expected limit of #{unmet_hrs_clg}."
        end
      else
        errs << "For #{type_desc} could not determine unmet hours; simulation may have failed."
      end

      # write errors to a log file
      File.open("#{File.dirname(__FILE__)}/output/#{type_desc}.log", 'w') do |file|
        errs.each { |err| file.puts(err) }
      end
      puts "'#{type_desc}.log' saved to #{File.dirname(__FILE__)}/output/#{type_desc}.log}."
    end

    #Throw assert if any errors.
    assert(errs.size == 0, errs.join("\n"))

    return true
  end

end

# copied and modified from https://github.com/rubyworks/facets/blob/master/lib/core/facets/string/snakecase.rb
class String
  def snake
    #gsub(/::/, '/').
    gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2').
        gsub(/([a-z\d])([A-Z])/, '\1_\2').
        tr('-', '_').
        gsub(/\s/, '_').
        gsub(/__+/, '_').
        gsub(/#+/, '').
        gsub(/\"/, '').
        downcase
  end
end